-- Lab 06 — Tables, Data Types and Constraints
-- Student: Aizirek Myrzabayeva
-- Dataset: fictional participants in campus learning workshops.
-- Run from postgres via psql-demo.sql.
-- IMPORTANT: Re-running resets ONLY lab06.workshop_member and lab06.course_member.

CREATE SCHEMA IF NOT EXISTS lab06;

-- Clean up only the tables owned by this exercise for a repeatable demonstration.
DROP TABLE IF EXISTS lab06.workshop_member;
DROP TABLE IF EXISTS lab06.course_member;

-- Demonstrate column types and common constraints.
CREATE TABLE lab06.course_member (
    member_id SERIAL PRIMARY KEY,
    registration_code BIGINT NOT NULL UNIQUE,
    first_name VARCHAR(40) NOT NULL,
    last_name VARCHAR(60) NOT NULL,
    email VARCHAR(120) NOT NULL,
    program VARCHAR(80),
    progress_score NUMERIC(5, 2),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    registered_on DATE NOT NULL DEFAULT CURRENT_DATE,
    last_checkin TIMESTAMP,
    notes TEXT,
    CONSTRAINT uq_lab06_email_original UNIQUE (email)
);

INSERT INTO lab06.course_member (
    registration_code, first_name, last_name, email,
    program, progress_score, last_checkin, notes
)
VALUES
    (20260001001, 'Adina', 'Kasymova', 'adina.kasymova@example.edu',
     'Web Development', 88.75, TIMESTAMP '2026-10-19 10:30:00', 'Autumn workshop'),
    (20260001002, 'Murat', 'Tulegenov', 'murat.tulegenov@example.edu',
     'Data Fundamentals', 94.25, TIMESTAMP '2026-10-20 14:15:00', 'Evening cohort');

-- ALTER TABLE: add a column and populate it.
ALTER TABLE lab06.course_member ADD COLUMN date_of_birth DATE;
UPDATE lab06.course_member
SET date_of_birth = DATE '2005-09-21'
WHERE registration_code = 20260001001;
UPDATE lab06.course_member
SET date_of_birth = DATE '2004-03-17'
WHERE registration_code = 20260001002;

-- ALTER TABLE: drop a column; change another column's data type.
ALTER TABLE lab06.course_member DROP COLUMN notes;
ALTER TABLE lab06.course_member ALTER COLUMN first_name TYPE TEXT;

-- ALTER TABLE: replace a constraint with an explicitly named constraint.
ALTER TABLE lab06.course_member DROP CONSTRAINT uq_lab06_email_original;
ALTER TABLE lab06.course_member
    ADD CONSTRAINT uq_lab06_email_address UNIQUE (email);
ALTER TABLE lab06.course_member
    ADD CONSTRAINT chk_lab06_progress_score
    CHECK (progress_score BETWEEN 0 AND 100);

-- ALTER TABLE: rename a column and the table.
ALTER TABLE lab06.course_member RENAME COLUMN email TO email_address;
ALTER TABLE lab06.course_member RENAME TO workshop_member;

-- Demonstrate constraints by deliberately attempting invalid inserts.
-- The expected exceptions are caught; any unexpectedly accepted row aborts the script.
DO $$
BEGIN
    BEGIN
        INSERT INTO lab06.workshop_member (
            registration_code, first_name, last_name, email_address
        ) VALUES (
            20260001003, 'Duplicate', 'Contact', 'adina.kasymova@example.edu'
        );
        RAISE EXCEPTION 'TEST FAILED: duplicate email was accepted';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'PASS: UNIQUE rejects a duplicate email address';
    END;

    BEGIN
        INSERT INTO lab06.workshop_member (
            registration_code, first_name, last_name,
            email_address, progress_score
        ) VALUES (
            20260001004, 'Invalid', 'Score',
            'invalid.score@example.edu', 125.00
        );
        RAISE EXCEPTION 'TEST FAILED: score over 100 was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS: CHECK rejects a score over 100';
    END;

    BEGIN
        INSERT INTO lab06.workshop_member (
            registration_code, first_name, last_name, email_address
        ) VALUES (
            20260001005, NULL, 'Name', 'missing.name@example.edu'
        );
        RAISE EXCEPTION 'TEST FAILED: NULL first name was accepted';
    EXCEPTION WHEN not_null_violation THEN
        RAISE NOTICE 'PASS: NOT NULL rejects a missing first name';
    END;
END $$;

-- Confirm the two valid records remain.
SELECT member_id, registration_code, first_name, last_name,
       email_address, progress_score, is_active, date_of_birth
FROM lab06.workshop_member
ORDER BY member_id;

-- DROP TABLE: create and remove a disposable table safely.
DROP TABLE IF EXISTS lab06.disposable_demo;
CREATE TABLE lab06.disposable_demo (id INTEGER PRIMARY KEY);
DROP TABLE lab06.disposable_demo;

-- Confirm a missing table is rejected when IF EXISTS is not supplied.
DO $$
BEGIN
    BEGIN
        DROP TABLE lab06.disposable_demo;
        RAISE EXCEPTION 'TEST FAILED: missing table was dropped';
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE 'PASS: DROP TABLE rejects a missing table';
    END;
END $$;

-- IF EXISTS allows safe cleanup even when no table is present.
DROP TABLE IF EXISTS lab06.disposable_demo;

-- A TEMP table lasts for this session only and is not in the persistent lab06 schema.
CREATE TEMP TABLE lab06_session_note (
    note_id INTEGER,
    description TEXT
);
INSERT INTO lab06_session_note VALUES
    (1, 'This row exists only during the current psql session');
SELECT * FROM lab06_session_note ORDER BY note_id;

-- Verify persistent tables and their final structure.
\dt lab06.*
\d lab06.workshop_member
