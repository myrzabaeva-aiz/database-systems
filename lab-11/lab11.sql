-- Lab 11: Basic Data Operations
-- Student: Aizirek Myrzabayeva
-- Case study: Campus Coding Club students (fictional data)
-- Safety: recreates only the isolated lab11 schema in the current database.
-- Run with psql from the database-systems repository root.

\set ON_ERROR_STOP on
\pset pager off

DROP SCHEMA IF EXISTS lab11 CASCADE;
CREATE SCHEMA lab11;

-- A simple student table for INSERT, UPDATE, DELETE and CSV exercises.
CREATE TABLE lab11.students (
    student_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    birth_date DATE,
    study_program VARCHAR(70) NOT NULL
);

-- 1. INSERT one student. RETURNING shows the row that was inserted.
INSERT INTO lab11.students (first_name, last_name, birth_date, study_program)
VALUES ('Adina', 'Kasymova', DATE '2004-02-18', 'Software Engineering')
RETURNING *;

-- 2. INSERT several students in one statement.
INSERT INTO lab11.students (first_name, last_name, birth_date, study_program)
VALUES
    ('Marat', 'Jumabaev', DATE '2003-11-20', 'Economics'),
    ('Saikal', 'Asanova', DATE '2005-01-08', 'Mathematics'),
    ('Emilbek', 'Niyazov', DATE '2002-06-25', 'Journalism')
RETURNING *;

-- 3. UPDATE only one student: WHERE prevents accidental changes to all rows.
UPDATE lab11.students
SET birth_date = DATE '2004-02-20'
WHERE student_id = 1
RETURNING *;

-- 4. DELETE one explicitly selected student.
DELETE FROM lab11.students
WHERE student_id = 4
RETURNING *;

-- 5. DELETE records matching a condition (one row in this dataset).
DELETE FROM lab11.students
WHERE birth_date < DATE '2004-01-01'
RETURNING *;

-- 6. Import 3 students from a local CSV file.
-- \copy is a psql client-side command; path is relative to repository root.
\copy lab11.students(first_name, last_name, birth_date, study_program) FROM 'lab-11/students.csv' WITH (FORMAT csv, HEADER true)

-- Inspect data immediately after the CSV import.
SELECT student_id, first_name, last_name, birth_date, study_program
FROM lab11.students
ORDER BY student_id;

-- 7. Bulk UPDATE: adjust the program label for three qualifying records.
UPDATE lab11.students
SET study_program = 'Computing'
WHERE study_program IN ('Software Engineering', 'Data Science')
RETURNING student_id, first_name, last_name, study_program;

-- 8. Bulk DELETE: remove two IDs in one statement.
DELETE FROM lab11.students
WHERE student_id IN (3, 6)
RETURNING student_id, first_name, last_name;

-- 9. Verify remaining data (3 rows expected).
SELECT student_id, first_name, last_name, birth_date, study_program
FROM lab11.students
ORDER BY student_id;

-- 10. Export the final result back to CSV (also client-side).
\copy (SELECT student_id, first_name, last_name, birth_date, study_program FROM lab11.students ORDER BY student_id) TO 'lab-11/output/final_students.csv' WITH (FORMAT csv, HEADER true)

-- Confirm the database structure and key.
\dt lab11.*
\d lab11.students
