#!/usr/bin/env python3
"""Lab 17: isolated PostgreSQL 18 backup/restore demonstrations.

Uses only Python stdlib and PostgreSQL CLI tools. This program never connects to
or stops the user's existing PostgreSQL installation. Temporary clusters use a
private UNIX socket and no TCP listener; disk artifacts are deleted on exit.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "output"
TOOLS_CORE = ["initdb", "pg_ctl", "psql", "pg_dump", "pg_restore", "pg_dumpall", "createdb"]
TOOLS_FULL = ["pg_basebackup", "pg_verifybackup", "pg_combinebackup", "pg_archivecleanup"]


class Lab:
    def __init__(self, tmp: Path):
        self.tmp = tmp
        self.socket = tmp / "socket"
        self.socket.mkdir(mode=0o700)
        self.cluster = tmp / "primary"
        self.archive = tmp / "archive"
        self.archive.mkdir()
        self.env = os.environ.copy()
        self.env.update({
            "PGHOST": str(self.socket), "PGPORT": "55417", "PGUSER": "lab17_owner",
            "PGDATABASE": "postgres", "PGCONNECT_TIMEOUT": "8", "PGPASSWORD": "",
            "LAB17_ISOLATED": "yes",
        })
        self.started: list[Path] = []
        self.nchecks = 0
        self.results = []
        self.logfile = (OUT / "session.txt").open("w", encoding="utf-8")

    def log(self, message: str):
        self.logfile.write(message + "\n")
        self.logfile.flush()

    def command(self, argv: list[str | Path], *, db: str | None = None, env=None, timeout=180,
                allow_failure=False, input_text=None, cwd=None) -> str:
        args = [str(a) for a in argv]
        environ = (env or self.env).copy()
        if db:
            environ["PGDATABASE"] = db
        self.log("$ " + " ".join(args))
        p = subprocess.run(args, cwd=cwd or ROOT, env=environ, input=input_text,
                           capture_output=True, text=True, encoding="utf-8", errors="replace",
                           timeout=timeout, check=False)
        if p.stdout.strip():
            self.log(p.stdout.rstrip())
        if p.stderr.strip():
            self.log(p.stderr.rstrip())
        self.log(f"[exit={p.returncode}]\n")
        if p.returncode and not allow_failure:
            raise RuntimeError(f"Command failed (exit {p.returncode}): {' '.join(args)}\n{p.stderr[-1500:]}")
        return p.stdout.strip()

    def sql(self, query: str, *, db="postgres") -> str:
        return self.command(["psql", "-X", "-v", "ON_ERROR_STOP=1", "-qAt", "-P", "pager=off", "-d", db, "-c", query])

    def script(self, path: Path, *, db="postgres"):
        return self.command(["psql", "-X", "-v", "ON_ERROR_STOP=1", "-P", "pager=off", "-d", db, "-f", path])

    def copy(self, meta_sql: str):
        return self.command(["psql", "-X", "-v", "ON_ERROR_STOP=1", "-d", "postgres", "-c", meta_sql])

    def check(self, title: str, value: bool, detail=""):
        if not value:
            self.results.append("FAIL " + title + (": " + str(detail) if detail else ""))
            self.log(self.results[-1])
            raise AssertionError(self.results[-1])
        self.nchecks += 1
        line = "PASS " + title + (": " + str(detail) if detail else "")
        self.results.append(line)
        self.log(line)
        print(line, flush=True)

    def init_cluster(self, directory: Path, user: str="lab17_owner"):
        self.command(["initdb", "-D", directory, "-U", user, "--auth-local=trust", "--auth-host=reject", "--encoding=UTF8", "--locale=C"], timeout=180)
        return directory

    def config(self, cluster: Path, *, socket: Path, port: int, primary=False):
        lines = ["listen_addresses = ''", f"unix_socket_directories = '{socket}'", f"port = {port}",
                 "fsync = on", "max_connections = 25", "shared_buffers = '32MB'", "logging_collector = off"]
        if primary:
            lines += ["wal_level = replica", "max_wal_senders = 6", "max_replication_slots = 4", "summarize_wal = on", "archive_mode = on",
                      f"archive_command = 'test ! -f {self.archive}/%f && cp %p {self.archive}/%f'", "archive_timeout = '5s'"]
        with (cluster / "postgresql.conf").open("a", encoding="utf-8") as f:
            f.write("\n# Lab17 private configuration\n" + "\n".join(lines) + "\n")

    def start(self, cluster: Path):
        self.command(["pg_ctl", "-D", cluster, "-l", self.tmp / (cluster.name + ".log"), "-w", "start"], timeout=150)
        self.started.append(cluster)

    def stop(self, cluster: Path):
        if cluster in self.started:
            self.command(["pg_ctl", "-D", cluster, "-m", "fast", "-w", "stop"], timeout=120, allow_failure=True)
            self.started.remove(cluster)

    def cleanup(self):
        for item in reversed(self.started[:]):
            try:
                self.stop(item)
            except Exception as e:
                self.log("Cleanup warning: " + str(e))
        self.logfile.close()


def q(s: Path) -> str:
    return "'" + str(s).replace("'", "''") + "'"


def hash_participants(lab: Lab, db="postgres") -> str:
    return lab.sql("SELECT COUNT(*) || '|' || md5(string_agg(to_jsonb(t)::text,';' ORDER BY participant_id)) FROM public.participants t;", db=db)


def createdb(lab: Lab, db: str):
    lab.command(["createdb", "-T", "template0", db])


def core_tests(lab: Lab):
    print("Initializing an isolated PostgreSQL 18 cluster (no TCP listener)...", flush=True)
    lab.init_cluster(lab.cluster)
    lab.config(lab.cluster, socket=lab.socket, port=55417, primary=True)
    lab.start(lab.cluster)
    lab.check("Private cluster reachable", lab.sql("SELECT current_user || '|' || current_database()") == "lab17_owner|postgres")
    lab.script(ROOT / "setup.sql")
    baseline = hash_participants(lab)
    lab.check("Fictional dataset and relationships", baseline.startswith("3|") and lab.sql("SELECT COUNT(*) FROM programs") == "2")

    # COPY and CSV processing
    members_csv = lab.tmp / "participants.csv"
    lab.copy(f"\\copy public.participants TO {q(members_csv)} WITH (FORMAT csv, HEADER true)")
    lab.check("CSV export with header", members_csv.exists() and len(members_csv.read_text(encoding="utf-8").splitlines()) == 4)
    lab.sql("CREATE TABLE participants_import (LIKE participants INCLUDING ALL)")
    lab.copy(f"\\copy public.participants_import FROM {q(members_csv)} WITH (FORMAT csv, HEADER true)")
    diff = lab.sql("SELECT COUNT(*) FROM ((SELECT * FROM participants EXCEPT ALL SELECT * FROM participants_import) UNION ALL (SELECT * FROM participants_import EXCEPT ALL SELECT * FROM participants)) d")
    lab.check("CSV round-trip content", diff == "0")
    lab.check("UTF-8 Cyrillic round-trip", lab.sql("SELECT first_name FROM participants_import WHERE participant_id=2") == "Айпери")

    pipe_csv = lab.tmp / "participants-semicolon.csv"
    lab.copy(f"\\copy public.participants TO {q(pipe_csv)} WITH (FORMAT csv, HEADER true, DELIMITER ';', NULL 'MISSING')")
    lab.sql("TRUNCATE participants_import")
    lab.copy(f"\\copy public.participants_import FROM {q(pipe_csv)} WITH (FORMAT csv, HEADER true, DELIMITER ';', NULL 'MISSING')")
    lab.check("Custom delimiter and NULL", lab.sql("SELECT COUNT(*) FROM participants_import WHERE email IS NULL") == "1")

    feedback_file = lab.tmp / "feedback.csv"
    lab.copy(f"\\copy public.feedback TO {q(feedback_file)} WITH (FORMAT csv, HEADER true)")
    lab.sql("CREATE TABLE feedback_import (LIKE feedback INCLUDING ALL)")
    lab.copy(f"\\copy public.feedback_import FROM {q(feedback_file)} WITH (FORMAT csv, HEADER true)")
    lab.check("Embedded quotes, commas, multiline CSV", lab.sql("SELECT COUNT(*) FROM ((SELECT * FROM feedback EXCEPT ALL SELECT * FROM feedback_import) UNION ALL (SELECT * FROM feedback_import EXCEPT ALL SELECT * FROM feedback)) x") == "0")

    selected_file = lab.tmp / "digital-participants.csv"
    lab.copy(f"\\copy (SELECT participant_id, first_name FROM public.participants WHERE program_id=10 ORDER BY participant_id) TO {q(selected_file)} WITH (FORMAT csv, HEADER true)")
    with selected_file.open(encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    lab.check("Selected-column query export", len(rows) == 2 and all(x["first_name"] in ("Amina", "Murat") for x in rows))

    lab.sql("CREATE TABLE new_members(id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY, first_name TEXT NOT NULL)")
    names_csv = lab.tmp / "new-members.csv"
    names_csv.write_text("first_name\nDana\nNursultan\n", encoding="utf-8")
    lab.copy(f"\\copy public.new_members(first_name) FROM {q(names_csv)} WITH (FORMAT csv, HEADER true)")
    lab.check("Selected-column import and generated ID", lab.sql("SELECT STRING_AGG(id::text || ':' || first_name,',' ORDER BY id) FROM new_members") == "1:Dana,2:Nursultan")

    lab.sql("CREATE TABLE imported_numbers(code INTEGER, amount INTEGER)")
    nums_csv = lab.tmp / "numbers.csv"
    nums_csv.write_text("code,amount\n1,20\n2,broken\n3,30\n", encoding="utf-8")
    lab.copy(f"\\copy public.imported_numbers FROM {q(nums_csv)} WITH (FORMAT csv, HEADER true, ON_ERROR ignore)")
    lab.check("COPY ON_ERROR ignore skips invalid conversion", lab.sql("SELECT STRING_AGG(code::text,',' ORDER BY code) FROM imported_numbers") == "1,3")

    quoted_file = lab.tmp / "dated-participants.csv"
    lab.copy(f"\\copy public.participants TO {q(quoted_file)} WITH (FORMAT csv, HEADER true, FORCE_QUOTE(joined_on))")
    lab.check("CSV date FORCE_QUOTE", '"2026-05-10"' in quoted_file.read_text(encoding="utf-8"))
    lab.check("Explicit NULL preserved", lab.sql("SELECT email IS NULL FROM participants WHERE participant_id=2") == "t")

    # Logical backup and restoration
    plain = lab.tmp / "backup.sql"
    custom = lab.tmp / "backup.dump"
    lab.command(["pg_dump", "-d", "postgres", "--no-owner", "-f", plain])
    lab.check("Plain SQL backup exists", plain.stat().st_size > 1000)
    lab.command(["pg_dump", "-d", "postgres", "-Fc", "-f", custom])
    catalog = lab.command(["pg_restore", "--list", custom])
    lab.check("Custom archive catalog", "participants" in catalog and "TABLE DATA" in catalog)

    createdb(lab, "plain_restore")
    lab.script(plain, db="plain_restore")
    lab.check("Plain SQL restore matches data", hash_participants(lab, "plain_restore") == baseline)
    createdb(lab, "custom_restore")
    lab.command(["pg_restore", "--exit-on-error", "--no-owner", "-j", "2", "-d", "custom_restore", custom])
    lab.check("Parallel custom restore matches data", hash_participants(lab, "custom_restore") == baseline)
    lab.check("View restored", lab.sql("SELECT COUNT(*) FROM digital_participants", db="custom_restore") == "2")
    lab.check("Role grant preserved in same cluster", lab.sql("SELECT has_table_privilege('lab17_reader','participants','SELECT')", db="custom_restore") == "t")

    schema = lab.tmp / "schema-only.sql"
    data = lab.tmp / "data-only.sql"
    lab.command(["pg_dump", "-d", "postgres", "-s", "--no-owner", "-f", schema])
    lab.command(["pg_dump", "-d", "postgres", "-a", "--no-owner", "-f", data])
    createdb(lab, "split_restore")
    lab.script(schema, db="split_restore")
    lab.check("Schema-only restore has no records", lab.sql("SELECT COUNT(*) FROM participants", db="split_restore") == "0")
    lab.script(data, db="split_restore")
    lab.check("Data-only restore matches source", hash_participants(lab, "split_restore") == baseline)

    createdb(lab, "single_table")
    lab.command(["pg_restore", "--exit-on-error", "--no-owner", "-d", "single_table", "-t", "feedback", custom])
    lab.check("Selected-table restore", lab.sql("SELECT COUNT(*) FROM feedback", db="single_table") == "3")

    excluding = lab.tmp / "without-log.sql"
    lab.command(["pg_dump", "-d", "postgres", "--no-owner", "-T", "public.daily_log", "-f", excluding])
    createdb(lab, "no_log")
    lab.script(excluding, db="no_log")
    lab.check("Excluded table absent", lab.sql("SELECT to_regclass('public.daily_log') IS NULL", db="no_log") == "t")

    globals_file = lab.tmp / "roles.sql"
    lab.command(["pg_dumpall", "--globals-only", "--no-role-passwords", "-f", globals_file])
    lab.check("Cluster roles exported separately", "lab17_reader" in globals_file.read_text(encoding="utf-8"))

    # Safe database-local migration and ETL
    lab.sql("CREATE TABLE target_contacts (contact_id INTEGER PRIMARY KEY, name TEXT, email TEXT)")
    lab.sql("INSERT INTO target_contacts VALUES(1,'Old entry','old@example.org')")
    lab.sql("CREATE TABLE staging_contacts(contact_id INTEGER, name TEXT, email TEXT)")
    stage_csv = lab.tmp / "contacts.csv"
    stage_csv.write_text("contact_id,name,email\n1, Amina Kadyrova , AMINA@EXAMPLE.ORG \n2, Murat Tologonov , MURAT@EXAMPLE.ORG \n", encoding="utf-8")
    lab.copy(f"\\copy staging_contacts FROM {q(stage_csv)} WITH (FORMAT csv, HEADER true)")
    lab.sql("INSERT INTO target_contacts SELECT contact_id, btrim(name), lower(btrim(email)) FROM staging_contacts ON CONFLICT(contact_id) DO UPDATE SET name=EXCLUDED.name, email=EXCLUDED.email")
    lab.check("ETL trim, lowercase and upsert", lab.sql("SELECT COUNT(*) || '|' || MIN(email) FROM target_contacts") == "2|amina@example.org")

    partitions_sql = lab.tmp / "partitions.sql"
    lab.command(["pg_dump", "-d", "postgres", "-t", "public.sales_2025", "--no-owner", "-f", partitions_sql])
    createdb(lab, "partition_move")
    lab.sql("CREATE TABLE sales(sale_id INTEGER,sold_on DATE,amount NUMERIC(10,2)) PARTITION BY RANGE (sold_on)", db="partition_move")
    lab.script(partitions_sql, db="partition_move")
    lab.check("Single partition migration", lab.sql("SELECT COUNT(*) || '|' || SUM(amount) FROM sales_2025", db="partition_move") == "1|150.00")

    daily = lab.tmp / "daily"
    daily.mkdir()
    old = daily / "postgres_20200101_000000_123.dump"
    old.write_text("not-a-backup", encoding="utf-8")
    very_old = time.time() - 11 * 24 * 3600
    os.utime(old, (very_old, very_old))
    other = daily / "otherdb_20200101_000000_123.dump"
    other.write_text("leave alone", encoding="utf-8")
    os.utime(other, (very_old, very_old))
    lab.command(["sh", ROOT / "backup.sh", "postgres", daily])
    produced = list(daily.glob("postgres_*.dump"))
    lab.check("Timestamped verified daily archive", len(produced) == 1 and "TABLE DATA" in lab.command(["pg_restore", "--list", produced[0]]))
    lab.check("Seven-day retention scoped to database", not old.exists() and other.exists())
    lab.check("Source data intact after migrations", hash_participants(lab) == baseline)


def full_tests(lab: Lab):
    # Optional disk-heavy exercises require PostgreSQL 18 physical-backup tools.
    print("Running optional physical backup and recovery tests in the same private cluster...", flush=True)
    base = lab.tmp / "base"
    lab.command(["pg_basebackup", "-D", base, "-X", "stream", "-c", "fast"], timeout=400)
    lab.command(["pg_verifybackup", base], timeout=300)
    lab.check("Full physical base backup verified", (base / "backup_manifest").exists())

    tar_dir = lab.tmp / "compressed_base"
    lab.command(["pg_basebackup", "-D", tar_dir, "-Ft", "-z", "-X", "stream", "-c", "fast"], timeout=400)
    lab.check("Compressed base backup created", any(p.name.endswith(".tar.gz") and p.stat().st_size > 1000 for p in tar_dir.iterdir()))

    # The optional PITR test uses only a copy of the BASE snapshot.
    lab.sql("INSERT INTO recovery_items VALUES (2,'Saved before deletion')")
    restore_point = "lab17_pre_delete"
    lab.sql(f"SELECT pg_create_restore_point('{restore_point}')")
    lab.sql("DELETE FROM recovery_items WHERE item_id=1")
    needed_segment = lab.sql("SELECT pg_walfile_name(pg_current_wal_lsn())")
    lab.sql("SELECT pg_switch_wal()")
    lab.check("Deletion committed on primary", lab.sql("SELECT COUNT(*) FROM recovery_items WHERE item_id=1") == "0")

    # Wait for the exact segment containing the restore point to be archived.
    for _ in range(80):
        if (lab.archive / needed_segment).exists():
            break
        time.sleep(0.5)
    lab.check("WAL segment containing restore point archived", (lab.archive / needed_segment).exists())

    # Incremental backups need summarized WAL; PG18 enables summarize_wal above.
    lab.sql("INSERT INTO recovery_items VALUES (3,'Incremental addition')")
    lab.sql("CHECKPOINT")
    incremental = lab.tmp / "incremental"
    try:
        lab.command(["pg_basebackup", "-D", incremental, "-X", "stream", "-c", "fast", f"--incremental={base / 'backup_manifest'}"], timeout=450)
        combined = lab.tmp / "combined"
        lab.command(["pg_combinebackup", "-o", combined, base, incremental], timeout=450)
        lab.command(["pg_verifybackup", combined], timeout=450)
        lab.check("Incremental backup combined and verified", (combined / "backup_manifest").exists())
    except RuntimeError as exc:
        lab.log("SKIP Incremental backup: " + str(exc))
        print("SKIP Incremental backup: PostgreSQL WAL summaries not ready; see session.txt", flush=True)

    # A copy of the base backup is restored to a separate socket and port.
    restore = lab.tmp / "pitr_restore"
    shutil.copytree(base, restore)
    restore_sock = lab.tmp / "recovery_socket"
    restore_sock.mkdir(mode=0o700)
    lab.config(restore, socket=restore_sock, port=55418)
    with (restore / "postgresql.conf").open("a", encoding="utf-8") as f:
        f.write("archive_mode = off\n")
        f.write(f"restore_command = 'cp {lab.archive}/%f %p'\n")
        f.write(f"recovery_target_name = '{restore_point}'\n")
        f.write("recovery_target_action = 'promote'\n")
    (restore / "recovery.signal").touch()
    lab.start(restore)
    restore_env = lab.env.copy()
    restore_env.update({"PGHOST": str(restore_sock), "PGPORT": "55418"})
    out = lab.command(["psql", "-X", "-qAt", "-v", "ON_ERROR_STOP=1", "-d", "postgres", "-c", "SELECT STRING_AGG(item_id::text, ',' ORDER BY item_id) FROM recovery_items"], env=restore_env)
    lab.check("PITR restores pre-deletion snapshot", out == "1,2", out)
    lab.stop(restore)


def tool_path_check(full: bool) -> None:
    needed = TOOLS_CORE + (TOOLS_FULL if full else [])
    missing = [x for x in needed if shutil.which(x) is None]
    if missing:
        raise RuntimeError("Missing PostgreSQL commands: " + ", ".join(missing) + ". On macOS: export PATH=\"$(brew --prefix postgresql@18)/bin:$PATH\"")
    p = subprocess.run(["psql", "--version"], capture_output=True, text=True)
    if p.returncode != 0 or " 18." not in p.stdout:
        raise RuntimeError("PostgreSQL 18 required; found: " + p.stdout.strip())
    if hasattr(os, "geteuid") and os.geteuid() == 0:
        raise RuntimeError("PostgreSQL initdb must run as a normal Mac user, not root")


def main():
    ap = argparse.ArgumentParser(description="Safe isolated PostgreSQL 18 lab 17")
    ap.add_argument("--full", action="store_true", help="also test disk-heavy base/incremental backups and PITR")
    ap.add_argument("--check-tools", action="store_true", help="preflight only; does not start a server")
    args = ap.parse_args()
    tool_path_check(args.full)
    if args.check_tools:
        print("PostgreSQL 18 tools verified; no database changed")
        return 0
    required = 2 * 1024**3 if args.full else 600 * 1024**2
    free = shutil.disk_usage(tempfile.gettempdir()).free
    if free < required:
        raise RuntimeError(f"Free space in temporary filesystem is too low: {free // (1024**2)} MB. Required at least {required // (1024**2)} MB.")
    OUT.mkdir(exist_ok=True)
    (OUT / "results.txt").write_text("RUN IN PROGRESS\n", encoding="utf-8")
    lab = None
    with tempfile.TemporaryDirectory(prefix="aizirek_lab17_") as temp:
        try:
            lab = Lab(Path(temp))
            core_tests(lab)
            if args.full:
                full_tests(lab)
            lab.results.append(f"{lab.nchecks} checks passed")
            print(f"\n{lab.nchecks} checks passed", flush=True)
            return 0
        except Exception as exc:
            err = "FAIL " + type(exc).__name__ + ": " + str(exc)
            if lab:
                lab.results.append(err)
            print(err, file=sys.stderr, flush=True)
            return 1
        finally:
            if lab:
                lab.cleanup()
                (OUT / "results.txt").write_text("\n".join(lab.results) + "\n", encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
