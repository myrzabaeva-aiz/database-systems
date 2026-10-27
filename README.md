# Database Systems — PostgreSQL Labs

A collection of **17 Database Systems laboratory assignments** completed as part of my Software Engineering coursework at the **American University of Central Asia (AUCA)**.

The labs progress from relational database fundamentals and PostgreSQL setup to database design, SQL queries, joins, transactions, and backup and recovery. Each lab has its own documentation and examples, following the [official course materials](https://drive.google.com/drive/folders/1xWdXTM-DHS33Xp8yfGxYs5w5pu1XZqEf).

## Environment

- **Operating system:** macOS
- **Database system:** PostgreSQL 18.6 (Homebrew)
- **Database administration:** pgAdmin 4 and `psql`
- **Development tools:** Visual Studio Code, Git and GitHub
- **Scripting:** SQL, Zsh and Python 3
- **Primary practice database:** `postgres` (with a separate schema for each applicable lab)

The commands below use the locally configured PostgreSQL role; no other student's username is required.

## Labs

- [Lab 01: Introduction to Relational Databases](lab-01/README.md)
- [Lab 02: Installing PostgreSQL and pgAdmin](lab-02/README.md)
- [Lab 03: Basic psql Commands](lab-03/README.md)
- [Lab 04: First SQL Query](lab-04/README.md)
- [Lab 05: Databases](lab-05/README.md)
- [Lab 06: Tables, Data Types and Constraints](lab-06/README.md)
- [Lab 07: Primary Keys](lab-07/README.md)
- [Lab 08: Foreign Keys and Relationships](lab-08/README.md)
- [Lab 09: Database Design Basics](lab-09/README.md)
- [Lab 10: Viewing Database and Table Structure](lab-10/README.md)
- [Lab 11: Basic Data Operations](lab-11/README.md)
- [Lab 12: Querying Data](lab-12/README.md)
- [Lab 13: Aggregate Functions](lab-13/README.md)
- [Lab 14: Joining Tables](lab-14/README.md)
- [Lab 15: Advanced Querying](lab-15/README.md)
- [Lab 16: Transactions and ACID Properties](lab-16/README.md)
- [Lab 17: Data Import, Export and Backup](lab-17/README.md)

## Running the Labs

Run the commands from the **repository root** (the directory containing this README). PostgreSQL must be installed and available on `PATH`.

### Labs 03–15: SQL and psql

Most practical labs include a `capture_labXX.sh` script that runs the SQL and saves the real terminal output. Use the command for the lab you want to inspect:

```bash
# Labs 03 and 04 share the Lab 03 example data.
zsh lab-03/capture_lab03.sh
psql -X -a -v ON_ERROR_STOP=1 -P pager=off -d postgres -f lab-04/lab04.sql

# Database management, constraints and relationships.
zsh lab-05/capture_lab05.sh
zsh lab-06/capture_lab06.sh
zsh lab-07/capture_lab07.sh
zsh lab-08/capture_lab08.sh

# Run Lab 09 before Lab 10 (Lab 10 inspects Lab 09's schema).
zsh lab-09/capture_lab09.sh
zsh lab-10/capture_lab10.sh

# Data manipulation, filtering, aggregation, joins and advanced SQL.
zsh lab-11/capture_lab11.sh
zsh lab-12/capture_lab12.sh
zsh lab-13/capture_lab13.sh
zsh lab-14/capture_lab14.sh
zsh lab-15/capture_lab15.sh
```

These are **individual examples**, not a requirement to rerun every lab. Most labs use their own schema so their data stays separate. Check each lab's README for any prerequisites and precise SQL entry point.

### Lab 16: Transactions and ACID

Lab 16 runs a Python demonstration with multiple PostgreSQL connections to test commits, rollbacks, savepoints, isolation, locking, deadlocks and recovery.

```bash
zsh lab-16/capture_lab16.sh
```

The demo uses a **temporary local PostgreSQL cluster**, rather than the existing practice database. Its results are saved to `lab-16/output/results.txt` and `lab-16/output/session.txt`.

### Lab 17: Import, Export and Backup

Lab 17 demonstrates CSV import/export, logical backup and restore, and migration. An optional full mode adds more resource-intensive physical backup and recovery experiments.

```bash
# Core demonstrations
zsh lab-17/capture_lab17.sh

# Optional: physical backup and recovery (allow at least 2 GB of free disk space)
zsh lab-17/capture_lab17.sh --full
```

Both modes use temporary PostgreSQL resources and write execution evidence to `lab-17/output/results.txt` and `lab-17/output/session.txt`. Some advanced replication concepts are documented rather than automated; the results file reports only checks actually executed.

If PostgreSQL 18 commands such as `initdb`, `pg_ctl`, or `pg_basebackup` are missing from `PATH` on macOS, use:

```bash
export PATH="$(brew --prefix postgresql@18)/bin:$PATH"
```

## Outputs and Evidence

Each practical lab includes an `output/` directory or equivalent evidence files. Depending on the lab, it contains:

- **Terminal logs:** actual `psql` or Python/PostgreSQL command output, not manually generated results.
- **Screenshots:** pgAdmin query results, table structures, ER diagrams or terminal checks.
- **Supporting files:** sample CSV data, ER diagrams and backup/restore verification logs, as relevant.

The screenshots and recorded outputs should be generated locally before submitting the repository. The Lab 09 ER diagram is also used as the foundation for Lab 10's schema inspection.

## Notes

- **Labs 01–02** focus on relational database concepts and local PostgreSQL installation.
- **Labs 03–04** work with the same `lab03` practice data.
- **Lab 05** demonstrates creating and managing a separate practice database.
- **Labs 06–09 and 11–15** use isolated demonstration schemas; rerunning their setup may replace data in the corresponding lab schema.
- **Lab 10** inspects the existing `lab09` schema without modifying it.
- **Labs 16–17** run advanced demonstrations against disposable local PostgreSQL clusters, separate from the regular coursework database.
- Sample people, organizations and other records are **fictional and used for educational purposes**.

## Author

**Aizirek Myrzabayeva**  
B.S. Software Engineering — American University of Central Asia

---

*Course reference: [Database Systems laboratory documents](https://drive.google.com/drive/folders/1xWdXTM-DHS33Xp8yfGxYs5w5pu1XZqEf).*
