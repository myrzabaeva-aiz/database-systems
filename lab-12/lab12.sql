-- Lab 12: Querying Data
-- Aizirek Myrzabayeva | Database Systems
-- Fictional dataset: Community Learning Center Operations
-- WARNING: Re-running recreates ONLY the lab12 schema.
-- No tables from previous laboratories are changed.

BEGIN;
DROP SCHEMA IF EXISTS lab12 CASCADE;
CREATE SCHEMA lab12;

-- Staff records for demonstrating SELECT and WHERE operations.
CREATE TABLE lab12.staff (
    staff_id INTEGER PRIMARY KEY,
    first_name VARCHAR(60) NOT NULL,
    last_name VARCHAR(60) NOT NULL,
    team_name VARCHAR(40) NOT NULL,
    team_code INTEGER NOT NULL,
    monthly_pay NUMERIC(10,2) NOT NULL CHECK (monthly_pay >= 0),
    email VARCHAR(120) UNIQUE,
    age INTEGER CHECK (age >= 18),
    joined_on DATE NOT NULL,
    years_experience INTEGER NOT NULL CHECK (years_experience >= 0),
    performance_bonus NUMERIC(10,2),
    mentor_id INTEGER REFERENCES lab12.staff(staff_id)
);

INSERT INTO lab12.staff
    (staff_id, first_name, last_name, team_name, team_code, monthly_pay,
     email, age, joined_on, years_experience, performance_bonus, mentor_id)
VALUES
    (1, 'Amina', 'Asanova', 'Digital', 10, 95000,
     'amina.asanova@example.org', 36, DATE '2020-01-15', 12, 6000, NULL),
    (2, 'Bekzat', 'Ismailov', 'Digital', 10, 72000,
     'bekzat.ismailov@example.org', 29, DATE '2022-06-01', 6, NULL, 1),
    (3, 'Elina', 'Toktosunova', 'Training', 20, 65000,
     NULL, 27, DATE '2023-02-10', 5, 2000, 1),
    (4, 'Marat', 'Orozov', 'Training', 20, 45000,
     'marat.orozov@example.org', 25, DATE '2024-04-20', 2, 0, 3),
    (5, 'Sabina', 'Nurmatova', 'Support', 30, 39000,
     'sabina.nurmatova@example.org', 42, DATE '2021-07-08', 15, NULL, 1),
    (6, 'Bektur', 'Osmonov', 'Training', 20, 61000,
     'bektur.osmonov@example.org', 30, DATE '2022-11-02', 7, 3000, 3),
    (7, 'Aida', 'Karimova', 'Training', 20, 54000,
     'aida.karimova@example.org', 24, DATE '2025-01-14', 3, NULL, 3),
    (8, 'Ruslan', 'Kasymov', 'Training', 20, 48000,
     'ruslan.kasymov@example.org', 33, DATE '2023-09-05', 9, 1200, 3),
    (9, 'Dana', 'Bolotova', 'Training', 20, 58000,
     'dana.bolotova@example.org', 35, DATE '2021-05-19', 10, NULL, 3);

CREATE TABLE lab12.supplies (
    supply_id INTEGER PRIMARY KEY,
    supply_name VARCHAR(80) NOT NULL,
    category VARCHAR(40) NOT NULL,
    unit_cost NUMERIC(10,2) NOT NULL CHECK (unit_cost >= 0)
);
INSERT INTO lab12.supplies VALUES
    (1, 'Camera kit', 'Equipment', 2800),
    (2, 'Wireless microphone', 'Equipment', 2000),
    (3, 'Conference banner', 'Materials', 500),
    (4, 'Portable printer', 'Equipment', 4200),
    (5, 'ring light', 'Equipment', 1500);

CREATE TABLE lab12.contacts (
    contact_id INTEGER PRIMARY KEY,
    contact_name VARCHAR(60) NOT NULL,
    email VARCHAR(120) NOT NULL
);
INSERT INTO lab12.contacts VALUES
    (1, 'Bella', 'Bella@GMAIL.COM'),
    (2, 'Belen', 'belen@example.org'),
    (3, 'bella', 'bella@example.org'),
    (4, 'Farida', 'farida@Gmail.com'),
    (5, 'NoEmail', 'invalid-address');

CREATE TABLE lab12.contributions (
    contribution_id INTEGER PRIMARY KEY,
    staff_id INTEGER NOT NULL REFERENCES lab12.staff(staff_id),
    contribution_value NUMERIC(10,2) NOT NULL CHECK (contribution_value >= 0),
    activity_date DATE NOT NULL
);
INSERT INTO lab12.contributions VALUES
    (1, 3, 1500, DATE '2026-09-02'),
    (2, 3, 900, DATE '2026-09-20'),
    (3, 4, 500, DATE '2026-09-25'),
    (4, 6, 1900, DATE '2026-10-02');
COMMIT;

-- ================================================================
-- Part A. SELECT, aliases, calculations
-- ================================================================
-- A1: Show every column (9 rows).
SELECT * FROM lab12.staff ORDER BY staff_id;

-- A2: Select only the columns needed by a report.
SELECT first_name, team_name FROM lab12.staff ORDER BY staff_id;

-- A3: Rename a calculated column with AS (10 percent of pay).
SELECT first_name, monthly_pay,
       ROUND(monthly_pay * 0.10, 2) AS estimated_bonus
FROM lab12.staff ORDER BY staff_id;

-- ================================================================
-- Part B. WHERE, comparisons, logic, ranges, NULL
-- ================================================================
-- B1: Equality.
SELECT first_name, monthly_pay FROM lab12.staff
WHERE team_name = 'Training' ORDER BY staff_id;

-- B2: Comparison and AND.
SELECT first_name, monthly_pay FROM lab12.staff
WHERE monthly_pay > 70000 AND team_name = 'Digital' ORDER BY staff_id;

-- B3: Inclusive range and not-equal operator.
SELECT first_name, monthly_pay FROM lab12.staff
WHERE monthly_pay BETWEEN 50000 AND 75000 AND monthly_pay <> 65000
ORDER BY monthly_pay DESC;

-- B4: OR and NOT.
SELECT first_name, team_name FROM lab12.staff
WHERE monthly_pay < 40000 OR NOT team_name = 'Training'
ORDER BY staff_id;

-- B5: BETWEEN includes both endpoints.
SELECT supply_name, unit_cost FROM lab12.supplies
WHERE unit_cost BETWEEN 1000 AND 3000 ORDER BY supply_id;

-- B6: Missing values require IS NULL, not = NULL.
SELECT first_name FROM lab12.staff WHERE email IS NULL;

-- B7: Show rows with an email.
SELECT first_name FROM lab12.staff WHERE email IS NOT NULL ORDER BY staff_id;

-- ================================================================
-- Part C. LIKE, ILIKE, regular expressions
-- ================================================================
-- C1: LIKE is case-sensitive and % matches zero or more characters.
SELECT contact_name FROM lab12.contacts
WHERE contact_name LIKE 'Be%' ORDER BY contact_name;

-- C2: Suffix pattern.
SELECT supply_name FROM lab12.supplies
WHERE supply_name LIKE '%light' ORDER BY supply_id;

-- C3: _ matches exactly one character.
SELECT contact_name FROM lab12.contacts
WHERE contact_name LIKE 'B_l%' ORDER BY contact_name;

-- C4: ILIKE ignores letter case in PostgreSQL.
SELECT contact_name, email FROM lab12.contacts
WHERE email ILIKE '%@gmail.com' ORDER BY contact_id;

-- C5: ~ is a case-sensitive regular-expression match.
SELECT first_name FROM lab12.staff
WHERE first_name ~ '^[AB]' ORDER BY staff_id;

-- C6: ~* is case-insensitive; illustrative pattern, not full email validation.
SELECT email FROM lab12.contacts
WHERE email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
ORDER BY contact_id;

-- C7: !~* excludes a case-insensitive regex match.
SELECT email FROM lab12.contacts
WHERE email !~* '@gmail\.com$' ORDER BY contact_id;

-- C8: !~ excludes a case-sensitive regex match.
SELECT first_name FROM lab12.staff
WHERE first_name !~ '^[AB]' ORDER BY staff_id;

-- ================================================================
-- Part D. IN, EXISTS, CASE, Common Table Expressions
-- ================================================================
-- D1: IN with static values.
SELECT first_name, team_name FROM lab12.staff
WHERE team_code IN (10, 20) ORDER BY staff_id;

-- D2: IN with a subquery - staff with contributions above 1000.
SELECT first_name FROM lab12.staff
WHERE staff_id IN (
    SELECT staff_id FROM lab12.contributions WHERE contribution_value > 1000
) ORDER BY staff_id;

-- D3: Correlated EXISTS - same staff as D2.
SELECT s.first_name FROM lab12.staff AS s
WHERE EXISTS (
    SELECT 1 FROM lab12.contributions AS c
    WHERE c.staff_id = s.staff_id AND c.contribution_value > 1000
) ORDER BY s.staff_id;

-- D4: CASE builds categories without modifying stored records.
SELECT first_name, monthly_pay,
       CASE
           WHEN monthly_pay >= 85000 THEN 'Lead'
           WHEN monthly_pay >= 55000 THEN 'Specialist'
           ELSE 'Associate'
       END AS pay_band
FROM lab12.staff ORDER BY staff_id;

-- D5: CTE computes average pay by team, then filters above-average staff.
WITH team_averages AS (
    SELECT team_name, AVG(monthly_pay) AS average_pay
    FROM lab12.staff GROUP BY team_name
)
SELECT s.first_name, s.team_name, s.monthly_pay,
       ROUND(t.average_pay, 2) AS team_average
FROM lab12.staff AS s
JOIN team_averages AS t USING (team_name)
WHERE s.monthly_pay > t.average_pay
ORDER BY s.team_name, s.first_name;

-- D6: Controlled result size for readable reports.
SELECT first_name, monthly_pay FROM lab12.staff
ORDER BY monthly_pay DESC, first_name LIMIT 3;
