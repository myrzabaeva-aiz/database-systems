#!/usr/bin/env python3
"""Lab 16: ACID transaction experiments in an isolated temporary PostgreSQL server.

Uses only Python's standard library plus PostgreSQL command line tools.
Never contacts or stops the user's existing PostgreSQL service.
"""
from __future__ import annotations

import os
import re
import select
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

LAB_DIR = Path(__file__).resolve().parent
OUTPUT = LAB_DIR / "output"
LOG_LINES: list[str] = []
CHECKS: list[tuple[bool, str, str]] = []
LOG_LOCK = threading.Lock()
RUN_ID = 0


def log(message: str = "") -> None:
    with LOG_LOCK:
        LOG_LINES.append(message)
        print(message, flush=True)


def verify(label: str, condition: bool, detail: str) -> None:
    CHECKS.append((condition, label, detail))
    log(f"{'PASS' if condition else 'FAIL'} {label}: {detail}")
    if not condition:
        raise AssertionError(f"{label}: {detail}")


def tool(name: str) -> str:
    found = shutil.which(name)
    if found:
        return found
    for prefix in ("/opt/homebrew/opt/postgresql@18/bin", "/usr/local/opt/postgresql@18/bin"):
        candidate = Path(prefix) / name
        if candidate.is_file():
            return str(candidate)
    raise RuntimeError(f"Cannot find {name}. Add PostgreSQL 18 bin to PATH: export PATH=\"$(brew --prefix postgresql@18)/bin:$PATH\"")


def command(args: list[str], env: dict[str, str] | None = None, timeout: float = 25,
            check: bool = True) -> subprocess.CompletedProcess[str]:
    log("$ " + " ".join(args))
    proc = subprocess.run(args, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, env=env, timeout=timeout)
    if proc.stdout.strip():
        log(proc.stdout.rstrip())
    if check and proc.returncode != 0:
        raise RuntimeError(f"Command returned {proc.returncode}: {args[0]}")
    return proc


class PsqlSession:
    def __init__(self, label: str, psql: str, env: dict[str, str]):
        self.label = label
        self.counter = 0
        self.remaining = b""
        self.proc = subprocess.Popen([psql, "-X", "-qAt", "-P", "pager=off", "-v", "ON_ERROR_STOP=0"],
                                     stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                     stderr=subprocess.STDOUT, env=env, bufsize=0)
        assert self.proc.stdin is not None and self.proc.stdout is not None

    def run(self, sql: str, timeout: float = 12) -> tuple[str, str]:
        self.counter += 1
        label = f"{self.label}_{self.counter}"
        state_token = "__STATE_" + label + "__"
        done_token = "__DONE_" + label + "__"
        sql = sql.strip()
        payload = (sql + "\n\\echo " + state_token + " :SQLSTATE\n\\echo " + done_token + "\n").encode()
        self.proc.stdin.write(payload)
        self.proc.stdin.flush()
        deadline = time.monotonic() + timeout
        needle = (done_token + "\n").encode()
        while needle not in self.remaining:
            remaining_time = deadline - time.monotonic()
            if remaining_time <= 0:
                raise TimeoutError(f"psql {self.label} timed out executing {sql[:120]}")
            ready, _, _ = select.select([self.proc.stdout.fileno()], [], [], remaining_time)
            if not ready:
                raise TimeoutError(f"psql {self.label} timed out executing {sql[:120]}")
            data = os.read(self.proc.stdout.fileno(), 8192)
            if not data:
                raise RuntimeError(f"psql {self.label} exited unexpectedly: {self.proc.poll()}")
            self.remaining += data
        prefix, self.remaining = self.remaining.split(needle, 1)
        text = prefix.decode("utf-8", errors="replace").strip()
        match = re.search(re.escape(state_token) + r"\s+([A-Z0-9]{5})", text)
        state = match.group(1) if match else "UNKNOWN"
        display = re.sub(r"\n?" + re.escape(state_token) + r"\s+[A-Z0-9]{5}", "", text).strip()
        log(f"[{self.label}] {sql}\n{display}\nstate={state}" if display else f"[{self.label}] {sql}\nstate={state}")
        return display, state

    def close(self) -> None:
        if self.proc.poll() is None:
            try:
                self.proc.stdin.write(b"\\q\n")
                self.proc.stdin.flush()
                self.proc.communicate(timeout=3)
            except (OSError, subprocess.TimeoutExpired, ValueError):
                self.proc.kill()
                self.proc.communicate()


def raw_value(psql: str, env: dict[str, str], query: str) -> str:
    p = command([psql, "-X", "-qAt", "-v", "ON_ERROR_STOP=1", "-c", query], env=env)
    return p.stdout.strip()


def balances(psql: str, env: dict[str, str]) -> str:
    return raw_value(psql, env, "SELECT string_agg(wallet_id || ':' || balance, ', ' ORDER BY wallet_id) FROM wallets;")


def find_socket_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def perform(psql: str, env: dict[str, str], ctl: str, data_dir: Path, log_file: Path,
            socket_dir: Path, port: int) -> None:
    a, b = PsqlSession("A", psql, env), PsqlSession("B", psql, env)
    try:
        a.run("BEGIN;")
        a.run("SELECT transfer_budget(1,2,500);")
        a.run("COMMIT;")
        actual = balances(psql, env)
        verify("COMMIT transfer", actual == "1:500.00, 2:1500.00", actual)

        a.run("BEGIN;")
        a.run("SELECT transfer_budget(2,1,100);")
        a.run("ROLLBACK;")
        actual = balances(psql, env)
        verify("ROLLBACK transfer", actual == "1:500.00, 2:1500.00", actual)

        a.run("BEGIN;")
        _, state = a.run("SELECT transfer_budget(1,2,9999);")
        a.run("ROLLBACK;")
        actual = raw_value(psql, env, "SELECT sum(balance) FROM wallets;")
        verify("Insufficient funds rejected", state == "P0001" and actual == "2000.00", f"SQLSTATE={state}; total={actual}")

        a.run("BEGIN;")
        a.run("INSERT INTO reservations VALUES (10,1,300);")
        a.run("INSERT INTO reservation_items VALUES (10,101,20);")
        _, state = a.run("UPDATE inventory SET units_available=units_available-20 WHERE equipment_id=101;")
        a.run("ROLLBACK;")
        actual = raw_value(psql, env, "SELECT (SELECT count(*) FROM reservations), (SELECT count(*) FROM reservation_items), units_available FROM inventory;")
        verify("Atomic inventory rollback", state == "23514" and actual == "0|0|10", f"SQLSTATE={state}; {actual}")

        a.run("BEGIN;")
        _, state = a.run("INSERT INTO reservations VALUES (11,999,100);")
        a.run("ROLLBACK;")
        actual = raw_value(psql, env, "SELECT count(*) FROM reservations;")
        verify("Foreign key consistency", state == "23503" and actual == "0", f"SQLSTATE={state}; remaining={actual}")

        a.run("BEGIN;")
        a.run("INSERT INTO participants VALUES (2,'Ermek Tashiev','ermek@example.org');")
        a.run("SAVEPOINT after_participant;")
        a.run("INSERT INTO reservations VALUES (20,2,500);")
        a.run("ROLLBACK TO SAVEPOINT after_participant;")
        a.run("INSERT INTO reservations VALUES (21,2,300);")
        a.run("COMMIT;")
        actual = raw_value(psql, env, "SELECT p.full_name || ':' || r.total_cost FROM participants p JOIN reservations r USING(participant_id) WHERE p.participant_id=2;")
        verify("Savepoint keeps participant, replaces reservation", actual == "Ermek Tashiev:300.00", actual)

        a.run("BEGIN;")
        a.run("INSERT INTO equipment VALUES (1,'Webcam',80);")
        a.run("SAVEPOINT sp_one;")
        a.run("INSERT INTO equipment VALUES (2,'Microphone',35);")
        a.run("SAVEPOINT sp_two;")
        _, state = a.run("INSERT INTO equipment VALUES (3,'Invalid item',-5);")
        a.run("ROLLBACK TO SAVEPOINT sp_two;")
        a.run("INSERT INTO equipment VALUES (4,'Projector',250);")
        a.run("RELEASE SAVEPOINT sp_one;")
        a.run("COMMIT;")
        actual = raw_value(psql, env, "SELECT string_agg(equipment_name, ', ' ORDER BY equipment_id) FROM equipment WHERE equipment_id < 100;")
        verify("Nested savepoints", state == "23514" and actual == "Webcam, Microphone, Projector", f"SQLSTATE={state}; {actual}")

        a.run("BEGIN;")
        a.run("INSERT INTO activity_logs VALUES ('Workshop registration started');")
        a.run("SAVEPOINT started;")
        a.run("INSERT INTO activity_logs VALUES ('Workshop registration completed');")
        a.run("RELEASE SAVEPOINT started;")
        a.run("COMMIT;")
        actual = raw_value(psql, env, "SELECT count(*) FROM activity_logs;")
        verify("RELEASE SAVEPOINT retains changes", actual == "2", actual)

        a.run("BEGIN;")
        a.run("INSERT INTO reservations VALUES (30,1,200);")
        a.run("SAVEPOINT before_items;")
        _, state = a.run("INSERT INTO reservation_items VALUES (30,999,1);")
        a.run("ROLLBACK TO SAVEPOINT before_items;")
        a.run("INSERT INTO reservation_items VALUES (30,101,2);")
        a.run("UPDATE inventory SET units_available=units_available-2 WHERE equipment_id=101;")
        a.run("COMMIT;")
        actual = raw_value(psql, env, "SELECT ri.quantity || '|' || i.units_available FROM reservation_items ri JOIN inventory i USING(equipment_id) WHERE ri.reservation_id=30;")
        verify("Reservation items recovered after rollback", state == "23503" and actual == "2|8", f"SQLSTATE={state}; {actual}")

        a.run("BEGIN;")
        a.run("INSERT INTO audit_log(action) VALUES ('new_user');")
        a.run("INSERT INTO users VALUES (1,'Adina Bekova');")
        a.run("INSERT INTO user_preferences VALUES (1,'dark');")
        a.run("COMMIT;")
        actual = raw_value(psql, env, "SELECT (SELECT count(*) FROM users), (SELECT count(*) FROM user_preferences), (SELECT count(*) FROM audit_log);")
        verify("User preferences and audit committed", actual == "1|1|1", actual)

        # READ UNCOMMITTED in PostgreSQL behaves like READ COMMITTED.
        a.run("BEGIN;")
        a.run("UPDATE wallets SET balance=600 WHERE wallet_id=1;")
        b.run("BEGIN ISOLATION LEVEL READ UNCOMMITTED;")
        observed, _ = b.run("SELECT balance FROM wallets WHERE wallet_id=1;")
        b.run("COMMIT;")
        a.run("ROLLBACK;")
        verify("READ UNCOMMITTED prevents dirty reads", observed == "500.00", observed)

        a.run("BEGIN ISOLATION LEVEL READ COMMITTED;")
        before, _ = a.run("SELECT balance FROM wallets WHERE wallet_id=1;")
        b.run("UPDATE wallets SET balance=600 WHERE wallet_id=1;")
        after, _ = a.run("SELECT balance FROM wallets WHERE wallet_id=1;")
        a.run("COMMIT;")
        verify("READ COMMITTED sees later committed changes", (before, after) == ("500.00", "600.00"), f"{before} -> {after}")

        a.run("BEGIN ISOLATION LEVEL REPEATABLE READ;")
        first, _ = a.run("SELECT balance FROM wallets WHERE wallet_id=1;")
        count_before, _ = a.run("SELECT count(*) FROM wallets;")
        b.run("UPDATE wallets SET balance=700 WHERE wallet_id=1;")
        b.run("INSERT INTO wallets VALUES (3,'Emergency Budget',50);")
        again, _ = a.run("SELECT balance FROM wallets WHERE wallet_id=1;")
        count_after, _ = a.run("SELECT count(*) FROM wallets;")
        a.run("COMMIT;")
        verify("REPEATABLE READ stable snapshot", (first, count_before, again, count_after) == ("600.00", "2", "600.00", "2"), f"{first}/{count_before} -> {again}/{count_after}")

        a.run("SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL REPEATABLE READ;")
        a.run("BEGIN;")
        level, _ = a.run("SHOW transaction_isolation;")
        a.run("COMMIT;")
        a.run("SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL READ COMMITTED;")
        verify("Session default isolation", level == "repeatable read", level)

        a.run("BEGIN ISOLATION LEVEL SERIALIZABLE;")
        ca, _ = a.run("SELECT count(*) FROM facilitators_on_duty WHERE on_duty;")
        b.run("BEGIN ISOLATION LEVEL SERIALIZABLE;")
        cb, _ = b.run("SELECT count(*) FROM facilitators_on_duty WHERE on_duty;")
        a.run("UPDATE facilitators_on_duty SET on_duty=false WHERE facilitator_id=1;")
        a.run("COMMIT;")
        _, serial_state = b.run("UPDATE facilitators_on_duty SET on_duty=false WHERE facilitator_id=2;")
        # Depending on timing, PostgreSQL can report 40001 on UPDATE or COMMIT.
        if serial_state == "00000":
            _, serial_state = b.run("COMMIT;")
        b.run("ROLLBACK;")
        b.run("BEGIN ISOLATION LEVEL SERIALIZABLE;")
        b.run("UPDATE facilitators_on_duty SET on_duty=false WHERE facilitator_id=2 AND (SELECT count(*) FROM facilitators_on_duty WHERE on_duty)>1;")
        b.run("COMMIT;")
        duty = raw_value(psql, env, "SELECT count(*) FROM facilitators_on_duty WHERE on_duty;")
        verify("SERIALIZABLE conflict and whole-transaction retry", ca == "2" and cb == "2" and serial_state == "40001" and duty == "1", f"SQLSTATE={serial_state}; remaining_on_duty={duty}")

        # Two concurrent connections demonstrate a blocked update.
        a.run("BEGIN;")
        a.run("UPDATE wallets SET balance=balance+1 WHERE wallet_id=1;")
        b.run("BEGIN;")
        pid_a, _ = a.run("SELECT pg_backend_pid();")
        pid_b, _ = b.run("SELECT pg_backend_pid();")
        response: dict[str, object] = {}
        def blocked_update() -> None:
            try:
                response["result"] = b.run("UPDATE wallets SET balance=balance+1 WHERE wallet_id=1;", timeout=14)
            except BaseException as exc:
                response["error"] = exc
        t = threading.Thread(target=blocked_update, daemon=True)
        t.start()
        blocked = "f"
        for _ in range(20):
            time.sleep(0.15)
            blocked = raw_value(psql, env, f"SELECT {pid_a}=ANY(pg_blocking_pids({pid_b}));")
            if blocked == "t":
                break
        verify("Blocked transaction visible through pg_blocking_pids", blocked == "t", blocked)
        a.run("COMMIT;")
        t.join(timeout=15)
        if t.is_alive() or "error" in response:
            raise RuntimeError(f"Blocked update did not finish: {response}")
        b.run("COMMIT;")
        verify("Waiting update proceeds after unlock", response["result"][1] == "00000", str(response["result"][1]))

        # Intentional deadlock, handled without touching the user's own server.
        a.run("BEGIN;")
        a.run("UPDATE wallets SET balance=balance+1 WHERE wallet_id=1;")
        b.run("BEGIN;")
        b.run("UPDATE wallets SET balance=balance+1 WHERE wallet_id=2;")
        outcomes: dict[str, object] = {}
        def update_cross(session: PsqlSession, key: str, target: int) -> None:
            try:
                outcomes[key] = session.run(f"UPDATE wallets SET balance=balance+1 WHERE wallet_id={target};", timeout=14)
            except BaseException as exc:
                outcomes[key] = exc
        ta = threading.Thread(target=update_cross, args=(a,"A",2), daemon=True)
        tb = threading.Thread(target=update_cross, args=(b,"B",1), daemon=True)
        ta.start()
        time.sleep(0.1)
        tb.start()
        ta.join(14)
        tb.join(14)
        states = [outcomes[k][1] for k in ("A", "B") if isinstance(outcomes.get(k), tuple)]
        a.run("ROLLBACK;")
        b.run("ROLLBACK;")
        verify("Deadlock identified and handled", not ta.is_alive() and not tb.is_alive() and "40P01" in states, str(states))

    finally:
        a.close()
        b.close()

    before_crash = balances(psql, env)
    command([ctl, "-D", str(data_dir), "-m", "immediate", "-w", "stop"], timeout=30)
    command([ctl, "-D", str(data_dir), "-l", str(log_file), "-w", "start",
             "-o", f"-c listen_addresses='' -k {socket_dir} -p {port}"], timeout=35)
    after_crash = balances(psql, env)
    verify("COMMIT survives simulated server crash", before_crash == after_crash, f"before={before_crash}; after={after_crash}")


def main() -> int:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    initdb = pg_ctl = psql = None
    try:
        initdb, pg_ctl, psql = tool("initdb"), tool("pg_ctl"), tool("psql")
    except Exception as exc:
        log(f"FAIL prerequisites: {exc}")
        (OUTPUT / "results.txt").write_text(f"FAIL prerequisites: {exc}\n", encoding="utf-8")
        (OUTPUT / "session.txt").write_text("\n".join(LOG_LINES) + "\n", encoding="utf-8")
        return 1
    failed = False
    try:
        with tempfile.TemporaryDirectory(prefix="aizirek-lab16-") as temp:
            root = Path(temp)
            data_dir = root / "cluster"
            socket_dir = root / "socket"
            socket_dir.mkdir(mode=0o700)
            log_file = root / "server.log"
            port = find_socket_port()
            # Local unix-domain socket only; no external network listener.
            command([initdb, "-D", str(data_dir), "-U", "lab16_user", "--auth-local=trust",
                     "--auth-host=reject", "--encoding=UTF8", "--locale=C"], timeout=80)
            env = os.environ.copy()
            env.update({"PGHOST": str(socket_dir), "PGPORT": str(port),
                        "PGUSER": "lab16_user", "PGDATABASE": "postgres",
                        "PGCONNECT_TIMEOUT": "5"})
            try:
                command([pg_ctl, "-D", str(data_dir), "-l", str(log_file), "-w", "start",
                         "-o", f"-c listen_addresses='' -k {socket_dir} -p {port}"], timeout=35)
                command([psql, "-X", "-v", "ON_ERROR_STOP=1", "-f", str(LAB_DIR / "setup.sql")], env=env, timeout=35)
                perform(psql, env, pg_ctl, data_dir, log_file, socket_dir, port)
            finally:
                status = subprocess.run([pg_ctl, "-D", str(data_dir), "status"],
                                        capture_output=True, text=True)
                if status.returncode == 0:
                    command([pg_ctl, "-D", str(data_dir), "-m", "fast", "-w", "stop"], timeout=35)
    except Exception as exc:
        failed = True
        log(f"FAIL unexpected error: {type(exc).__name__}: {exc}")
    finally:
        total_ok = sum(ok for ok,_,_ in CHECKS)
        log(f"\n{total_ok}/{len(CHECKS)} checks passed")
        (OUTPUT / "results.txt").write_text(
            "Lab 16: Transactions and ACID Properties\n"
            "Student: Aizirek Myrzabayeva\n\n"
            + "\n".join(f"{'PASS' if ok else 'FAIL'} {label}: {detail}" for ok,label,detail in CHECKS)
            + f"\n\n{total_ok}/{len(CHECKS)} checks passed\n"
            + ("RUN FAILED — see session.txt\n" if failed else ""), encoding="utf-8")
        (OUTPUT / "session.txt").write_text("\n".join(LOG_LINES) + "\n", encoding="utf-8")
    return 1 if failed or any(not ok for ok,_,_ in CHECKS) else 0


if __name__ == "__main__":
    raise SystemExit(main())
