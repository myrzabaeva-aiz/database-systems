# Lab 1 — PostgreSQL Basics

**Student:** Aizirek Myrzabaeva  
**Course:** Database 

## Objective

The purpose of this laboratory work is to practice basic PostgreSQL operations using the `psql` command-line interface.

During this lab, I practiced connecting to PostgreSQL, working with databases and tables, inserting data, and retrieving data using SQL queries.

## Tasks Completed

1. Started PostgreSQL and connected to the PostgreSQL server.
2. Viewed the list of available databases.
3. Created a new database named `mydb`.
4. Connected to the `mydb` database.
5. Created a table named `students`.
6. Viewed the structure of the `students` table.
7. Inserted sample records into the table.
8. Retrieved the records using a `SELECT` query.
9. Practiced basic `psql` commands.

## Database Structure

The `students` table contains the following columns:

| Column | Type | Description |
|---|---|---|
| `id` | SERIAL | Primary key |
| `name` | VARCHAR(100) | Student name |
| `age` | INTEGER | Student age |

## SQL File

The SQL commands used in this laboratory work are stored in:

`basic_psql.sql`

Example SQL operations:

```sql
CREATE TABLE students (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    age INT
);

INSERT INTO students (name, age)
VALUES ('Alice', 21), ('Bob', 23);

SELECT * FROM students;