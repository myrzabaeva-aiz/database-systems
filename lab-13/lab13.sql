-- Lab 13: Aggregate Functions
-- Student: Aizirek Myrzabayeva
-- Fictional dataset: Community Learning Center (10 staff members)
-- IMPORTANT: Rerunning resets ONLY the lab13 schema and its contents.

\set ON_ERROR_STOP on
\pset pager off

DROP SCHEMA IF EXISTS lab13 CASCADE;
CREATE SCHEMA lab13;
SET search_path TO lab13, pg_catalog;

-- 1. Sample tables. NULL email and bonus values demonstrate NULL handling.
CREATE TABLE staff (
    staff_id INTEGER PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    team_name TEXT NOT NULL,
    monthly_pay NUMERIC(10,2) NOT NULL CHECK (monthly_pay > 0),
    email TEXT UNIQUE,
    age INTEGER NOT NULL CHECK (age BETWEEN 18 AND 75),
    hire_date DATE NOT NULL,
    experience_years INTEGER NOT NULL CHECK (experience_years >= 0),
    bonus NUMERIC(10,2)
);

INSERT INTO staff VALUES
(1, 'Amina',  'Iskenderova', 'Training',      68000, 'amina@example.org',  28, DATE '2019-03-12', 6, 4000),
(2, 'Beknur', 'Talipov',     'Training',      54000, 'beknur@example.org', 24, DATE '2024-02-18', 3, NULL),
(3, 'Elina',  'Tursunova',   'Training',      59000, 'elina@example.org',  32, DATE '2021-04-01', 8, 1500),
(4, 'Samat',  'Kadyrov',     'Training',      64000, 'samat@example.org',  36, DATE '2018-09-01', 10, 2500),
(5, 'Zarina', 'Akmatova',    'Training',      51000, 'zarina@example.org', 22, DATE '2025-07-10', 1, 0),
(6, 'Meerim', 'Osmonova',    'Digital Media', 72000, 'meerim@example.org', 30, DATE '2020-05-06', 7, 3500),
(7, 'Ruslan', 'Ibraev',      'Digital Media', 62000, NULL,                 27, DATE '2022-07-15', 5, NULL),
(8, 'Adina',  'Melisova',    'Digital Media', 58000, 'adina@example.org',  25, DATE '2023-11-03', 3, 1000),
(9, 'Timur',  'Bekov',       'Operations',    82000, 'timur@example.org',  42, DATE '2015-01-20', 16, 6000),
(10,'Aelita', 'Omurzakova',  'Operations',    47000, 'aelita@example.org', 23, DATE '2025-01-08', 2, NULL);

CREATE TABLE workshops (
    workshop_id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    fee NUMERIC(10,2) NOT NULL CHECK (fee >= 0)
);
INSERT INTO workshops VALUES
(1, 'Digital Safety',       'Technology',     500),
(2, 'Public Speaking',      'Communication', 350),
(3, 'Python Foundations',   'Technology',     900),
(4, 'Community Storytelling','Creative',      600);

CREATE TABLE activity_payments (
    payment_id INTEGER PRIMARY KEY,
    staff_id INTEGER NOT NULL REFERENCES staff(staff_id),
    amount NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    payment_date DATE NOT NULL
);
INSERT INTO activity_payments VALUES
(1, 1, 2400, DATE '2025-01-12'),
(2, 3, 1800, DATE '2025-03-15'),
(3, 6, 3150, DATE '2025-04-20'),
(4, 4, 2200, DATE '2025-10-02'),
(5, 7, 2750, DATE '2026-02-11'),
(6, 5, 1200, DATE '2026-07-05'),
(7, 9, 4200, DATE '2026-10-10');

CREATE TABLE staff_skills (
    staff_id INTEGER NOT NULL REFERENCES staff(staff_id),
    skill_name TEXT NOT NULL,
    PRIMARY KEY (staff_id, skill_name)
);
INSERT INTO staff_skills VALUES
(1, 'SQL'), (1, 'Training Design'), (2, 'Public Speaking'),
(3, 'Python'), (3, 'SQL'), (4, 'Mentoring'),
(6, 'Editing'), (6, 'Photography'), (7, 'Video Production'),
(9, 'Budgeting');

CREATE TABLE workshop_reviews (
    workshop_id INTEGER NOT NULL REFERENCES workshops(workshop_id),
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5)
);
INSERT INTO workshop_reviews VALUES
(1,5),(1,5),(1,4),(1,5),
(2,3),(2,4),
(3,5),(3,4),(3,5);

\echo ===== 01: COUNT(*) versus COUNT(column) and distinct teams =====
SELECT COUNT(*) AS staff_count,
       COUNT(email) AS recorded_emails,
       COUNT(*) - COUNT(email) AS missing_emails,
       COUNT(DISTINCT team_name) AS distinct_teams
FROM staff;

\echo ===== 02: SUM / AVG / MIN / MAX =====
SELECT SUM(monthly_pay) AS total_monthly_pay,
       ROUND(AVG(monthly_pay), 2) AS average_monthly_pay,
       MIN(monthly_pay) AS lowest_pay,
       MAX(monthly_pay) AS highest_pay
FROM staff;

\echo ===== 03: Team salary summary (main screenshot) =====
SELECT team_name, COUNT(*) AS staff_count,
       SUM(monthly_pay) AS total_monthly_pay,
       ROUND(AVG(monthly_pay), 2) AS average_monthly_pay,
       MIN(monthly_pay) AS min_pay,
       MAX(monthly_pay) AS max_pay
FROM staff
GROUP BY team_name
ORDER BY team_name;

\echo ===== 04: Activity payments grouped by team =====
SELECT s.team_name, COUNT(*) AS payments,
       SUM(p.amount) AS total_activity_payments
FROM activity_payments AS p
JOIN staff AS s USING (staff_id)
GROUP BY s.team_name
ORDER BY s.team_name;

\echo ===== 05: AVG(age) and MAX(hire_date) =====
SELECT team_name, ROUND(AVG(age), 2) AS average_age,
       MAX(hire_date) AS latest_hire
FROM staff
GROUP BY team_name
ORDER BY team_name;

\echo ===== 06: STRING_AGG and ARRAY_AGG =====
SELECT team_name,
       STRING_AGG(first_name, ', ' ORDER BY first_name) AS names,
       ARRAY_AGG(monthly_pay ORDER BY monthly_pay, staff_id) AS monthly_pays
FROM staff
GROUP BY team_name
ORDER BY team_name;

\echo ===== 07: Aggregate skills into a single string =====
SELECT staff_id,
       STRING_AGG(skill_name, ', ' ORDER BY skill_name) AS skills
FROM staff_skills
GROUP BY staff_id
ORDER BY staff_id;

\echo ===== 08: Standard deviation and sample variance =====
SELECT team_name,
       ROUND(STDDEV(monthly_pay), 2) AS pay_stddev,
       ROUND(VARIANCE(monthly_pay), 2) AS pay_variance
FROM staff
GROUP BY team_name
ORDER BY team_name;

\echo ===== 09: CORR(experience_years, monthly_pay) =====
SELECT ROUND(CORR(experience_years::DOUBLE PRECISION,
                  monthly_pay::DOUBLE PRECISION)::NUMERIC, 4)
       AS experience_pay_correlation
FROM staff;

\echo ===== 10: Multiple aggregates by workshop category =====
SELECT category, COUNT(*) AS workshops,
       SUM(fee) AS total_fees,
       ROUND(AVG(fee), 2) AS average_fee
FROM workshops
GROUP BY category
ORDER BY category;

\echo ===== 11: GROUP BY year and quarter =====
SELECT EXTRACT(YEAR FROM payment_date)::INT AS payment_year,
       EXTRACT(QUARTER FROM payment_date)::INT AS quarter,
       COUNT(*) AS payments,
       SUM(amount) AS total_amount
FROM activity_payments
GROUP BY 1, 2
ORDER BY 1, 2;

\echo ===== 12: GROUP BY calculated age bands =====
SELECT CASE WHEN age < 30 THEN 'Under 30'
            WHEN age <= 40 THEN '30-40'
            ELSE '41+'
       END AS age_group,
       COUNT(*) AS staff_count,
       ROUND(AVG(monthly_pay), 2) AS average_pay
FROM staff
GROUP BY 1
ORDER BY 1;

\echo ===== 13: HAVING filters a group after GROUP BY =====
SELECT team_name, COUNT(*) AS staff_count
FROM staff
GROUP BY team_name
HAVING COUNT(*) > 4
ORDER BY team_name;

\echo ===== 14: HAVING multiple conditions (ratings) =====
SELECT w.title, COUNT(*) AS review_count,
       ROUND(AVG(r.rating), 2) AS average_rating
FROM workshop_reviews AS r
JOIN workshops AS w USING (workshop_id)
GROUP BY w.workshop_id, w.title
HAVING AVG(r.rating) > 4 AND COUNT(*) >= 3
ORDER BY w.title;

\echo ===== 15: WHERE before grouping; HAVING after grouping =====
SELECT team_name, COUNT(*) AS recent_hires
FROM staff
WHERE hire_date >= DATE '2022-01-01'
GROUP BY team_name
HAVING COUNT(*) >= 2
ORDER BY team_name;

\echo ===== 16: Window aggregate preserves all individual rows =====
SELECT staff_id, first_name, team_name, monthly_pay,
       ROUND(AVG(monthly_pay) OVER (PARTITION BY team_name), 2)
           AS team_average_pay
FROM staff
ORDER BY staff_id;

\echo ===== 17: SUM and AVG ignore NULL bonus values =====
SELECT COUNT(*) AS all_staff,
       COUNT(bonus) AS reported_bonus_values,
       SUM(bonus) AS bonus_total,
       ROUND(AVG(bonus), 2) AS average_reported_bonus
FROM staff;

\echo ===== 18: Conditional aggregation and team percentages =====
SELECT team_name,
       COUNT(*) AS staff_count,
       COUNT(*) FILTER (WHERE monthly_pay >= 60000) AS pay_at_least_60000,
       COUNT(*) FILTER (WHERE hire_date >= DATE '2023-01-01') AS recent_hires,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM staff), 2)
           AS percent_of_staff
FROM staff
GROUP BY team_name
ORDER BY team_name;

\echo ===== 19: GROUP BY multiple columns =====
SELECT team_name, EXTRACT(YEAR FROM hire_date)::INT AS hire_year,
       COUNT(*) AS hires
FROM staff
GROUP BY team_name, EXTRACT(YEAR FROM hire_date)
ORDER BY team_name, hire_year;

\echo ===== 20: Final table list =====
\dt lab13.*

RESET search_path;
