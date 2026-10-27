# Lab 16: Transactions and ACID Properties

**Course:** Database Systems (AUCA)  
**Student:** Aizirek Myrzabayeva  
**Environment:** macOS, Python 3, PostgreSQL 18 command-line tools

## Overview

A transaction treats multiple SQL statements as one logical operation. This lab demonstrates `BEGIN`, `COMMIT`, `ROLLBACK`, `SAVEPOINT`, `ROLLBACK TO SAVEPOINT`, and `RELEASE SAVEPOINT` in an original **Community Learning Center** scenario. A Python driver starts an **isolated temporary PostgreSQL server** to run concurrent transactions without touching the normal local database installation.

Run from the repository root:

```bash
zsh lab-16/capture_lab16.sh
```

Alternatively, run `python3 lab-16/demo.py` or double-click `run.command` on macOS (if it is executable).

**Requirements:** Python 3 (standard library only), `initdb`, `pg_ctl`, and `psql` from PostgreSQL 18. No Python database package is required. If PostgreSQL binaries are missing from your `PATH`, on a Homebrew installation use:

```bash
export PATH="$(brew --prefix postgresql@18)/bin:$PATH"
```

## Dataset

Fictional tables initialized by [setup.sql](setup.sql):

| Table | Purpose |
| --- | --- |
| `wallets` | Two program budgets with nonnegative balances |
| `participants`, `reservations`, `reservation_items` | Related activity reservations, protected by foreign keys |
| `equipment`, `inventory` | Equipment with price and stock constraints |
| `users`, `user_preferences`, `audit_log`, `activity_logs` | Consistent multi-table updates and savepoint examples |
| `facilitators_on_duty` | Serializable transactions and write-skew prevention |

All records are fictional and used only for learning. The setup does not use any tables from Labs 1–15.

## Transaction tests

The [Python demo](demo.py) performs **19 checks** across the following subjects:

1. **Atomicity:** `COMMIT` saves a transfer; `ROLLBACK` restores balances. Rejected transfers, failed stock updates, and invalid foreign keys do not leave partial changes.
2. **Savepoints:** `SAVEPOINT` and `ROLLBACK TO` retain valid earlier work, while `RELEASE SAVEPOINT` keeps subsequent changes for the enclosing commit.
3. **Consistency:** `CHECK` and foreign-key constraints prevent negative balances, negative stock, and references to nonexistent participants or equipment.
4. **Isolation:** Two interactive connections verify no dirty reads, `READ COMMITTED` changes between statements, a stable `REPEATABLE READ` snapshot, and `SERIALIZABLE` conflict handling with a whole-transaction retry.
5. **Concurrency:** `pg_blocking_pids` detects a waiting update; a deliberately conflicting pair of updates demonstrates PostgreSQL SQLSTATE `40P01` for a deadlock.
6. **Durability:** The private test server is stopped with `pg_ctl -m immediate`, restarted, and queried to verify committed balances survive recovery.

### Important PostgreSQL details

- PostgreSQL's `READ UNCOMMITTED` behaves as `READ COMMITTED`, **so it does not expose dirty reads**.
- PostgreSQL's `REPEATABLE READ` also prevents phantom reads by holding a stable MVCC snapshot.
- `SET TRANSACTION` applies to a transaction after `BEGIN`; `SET SESSION CHARACTERISTICS` changes the default for later transactions.
- Serialization and deadlock failures require retrying the **entire transaction**, not merely the final SQL statement.
- The durability check simulates an immediate server stop and PostgreSQL WAL recovery. It is **not** a claim to simulate a real power failure.

## Results and output

After successfully running `capture_lab16.sh`, the demo generates **two actual text files**:

- [results.txt](output/results.txt) — one `PASS` or `FAIL` line per check and the total.
- [session.txt](output/session.txt) — complete command-by-command terminal log, including SQLSTATE codes and PostgreSQL's responses.

A successful run ends with `19/19 checks passed`. **These files are generated on your Mac; sample outputs have not been fabricated.** In case of a failure, consult `output/session.txt` before committing the lab.

Optional screenshots can be taken from the actual Terminal showing `19/19 checks passed` and the isolation/deadlock output; they are not required for these two links to work.

## Safe execution and cleanup

The script creates a fresh PostgreSQL cluster in a unique temporary directory with an owner-only Unix socket and **no TCP listener**. All data is disposable. It sends `pg_ctl` commands **only to that temporary cluster** (never to your Homebrew PostgreSQL service or existing data directory), then stops and deletes the temporary cluster. This means running it again replaces only that temporary test environment.

If `initdb` or `pg_ctl` is missing, the demo reports a missing prerequisite instead of connecting to another server. If a run fails unexpectedly, inspect the logs for details.

## Conclusions

PostgreSQL transactions make multi-statement operations reliable. Atomicity and consistency prevent partially applied or invalid changes; isolation specifies the visibility of concurrent work; durability preserves committed results across recovery. Savepoints offer partial recovery within a transaction, while stable lock ordering and full retries help applications deal with concurrency safely.

**References:** [Official AUCA Lab 16 course document](https://drive.google.com/file/d/1dgJPa86-PnyEBxg-cHCSPlxmeJ3an0oZ/view) · [PostgreSQL transaction isolation](https://www.postgresql.org/docs/18/transaction-iso.html) · [PostgreSQL SAVEPOINT](https://www.postgresql.org/docs/18/sql-savepoint.html)
