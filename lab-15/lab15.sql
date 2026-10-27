-- Lab 15: Advanced Querying
-- Student: Aizirek Myrzabayeva
-- Fictional case study: Youth Innovation Program Operations
-- WARNING: Rerunning this file replaces ONLY the lab15 schema and its objects.

DROP SCHEMA IF EXISTS lab15 CASCADE;
CREATE SCHEMA lab15;
SET search_path TO lab15, pg_catalog;

-- 1. Reproducible data for subqueries, hierarchies, and window functions.
CREATE TABLE staff (
    staff_id INTEGER PRIMARY KEY,
    first_name VARCHAR(60) NOT NULL,
    last_name VARCHAR(60) NOT NULL,
    team_name VARCHAR(40) NOT NULL,
    monthly_pay NUMERIC(10,2) NOT NULL CHECK (monthly_pay > 0),
    experience_years INTEGER NOT NULL CHECK (experience_years >= 0),
    email VARCHAR(120) UNIQUE,
    manager_id INTEGER REFERENCES staff(staff_id)
);

INSERT INTO staff (staff_id, first_name, last_name, team_name, monthly_pay,
                   experience_years, email, manager_id) VALUES
    (1, 'Alina',   'Idrisova',      'Programmes',   125000, 14, 'alina@demo.example', NULL),
    (2, 'Timur',   'Kasymov',      'Programmes',    90000,  8, 'timur@demo.example', 1),
    (3, 'Aigerim', 'Talantbek',    'Media',         80000,  7, 'aigerim@demo.example', 1),
    (4, 'Nurlan',  'Shadiev',      'Media',         60000,  2, 'nurlan@demo.example', 3),
    (5, 'Malika',  'Bekova',       'Partnerships',  55000,  5, 'malika@demo.example', 1),
    (6, 'Sezim',   'Abdykadyrova', 'Media',         80000,  8, 'sezim@demo.example', 3),
    (7, 'Daniyar', 'Usubov',       'Media',         70000,  4, 'daniyar@demo.example', 3),
    (8, 'Farida',  'Osmonova',     'Partnerships',  58000,  3, 'farida@demo.example', 5),
    (9, 'Elina',   'Chyngyz',      'Media',         50000,  1, 'elina@demo.example', 3);

CREATE TABLE contributions (
    contribution_id INTEGER PRIMARY KEY,
    staff_id INTEGER NOT NULL REFERENCES staff(staff_id),
    contribution_amount NUMERIC(10,2) NOT NULL CHECK (contribution_amount >= 0),
    contribution_date DATE NOT NULL
);
INSERT INTO contributions VALUES
    (1, 3, 1000.00, DATE '2026-03-05'),
    (2, 6, 750.00,  DATE '2026-03-12'),
    (3, 8, 400.00,  DATE '2026-04-01'),
    (4, 5, 1600.00, DATE '2026-04-09');

-- 2. Scalar subquery: employees earning above the organization average.
SELECT first_name, team_name, monthly_pay
FROM staff
WHERE monthly_pay > (SELECT AVG(monthly_pay) FROM staff)
ORDER BY monthly_pay DESC, staff_id;

-- 3. Row subquery: staff with the same (team, pay) as Aigerim.
SELECT first_name, team_name, monthly_pay
FROM staff
WHERE (team_name, monthly_pay) =
      (SELECT team_name, monthly_pay FROM staff WHERE staff_id = 3)
ORDER BY staff_id;

-- 4. Table subquery in FROM: teams above a chosen average-pay threshold.
SELECT team_name, ROUND(avg_pay, 2) AS average_pay
FROM (
    SELECT team_name, AVG(monthly_pay) AS avg_pay
    FROM staff
    GROUP BY team_name
) AS team_summary
WHERE avg_pay > 65000
ORDER BY team_name;

-- 5. CTE: team-level contributions greater than 1500.
WITH team_contributions AS (
    SELECT s.team_name, SUM(c.contribution_amount) AS total_amount
    FROM contributions AS c
    JOIN staff AS s USING (staff_id)
    GROUP BY s.team_name
)
SELECT team_name, total_amount
FROM team_contributions
WHERE total_amount > 1500
ORDER BY team_name;

-- 6. Recursive CTE: organizational hierarchy with a path-based cycle guard.
WITH RECURSIVE organization_chart AS (
    SELECT staff_id, first_name, manager_id,
           0 AS depth, ARRAY[staff_id] AS traversal_path
    FROM staff
    WHERE manager_id IS NULL
    UNION ALL
    SELECT s.staff_id, s.first_name, s.manager_id,
           o.depth + 1, o.traversal_path || s.staff_id
    FROM staff AS s
    JOIN organization_chart AS o ON s.manager_id = o.staff_id
    WHERE NOT s.staff_id = ANY(o.traversal_path)
)
SELECT staff_id, first_name, manager_id, depth
FROM organization_chart
ORDER BY traversal_path;

-- 7. Set operations: two overlapping equipment storage lists.
CREATE TABLE storage_a (
    item_id INTEGER PRIMARY KEY,
    item_name TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity >= 0)
);
CREATE TABLE storage_b (LIKE storage_a INCLUDING ALL);
INSERT INTO storage_a VALUES (10, 'Camera Kit', 0), (20, 'Wireless Microphone', 3);
INSERT INTO storage_b VALUES (10, 'Camera Kit', 0), (30, 'LED Panel', 5);

-- UNION discards duplicate Camera Kit; UNION ALL retains both rows.
SELECT item_name FROM storage_a
UNION
SELECT item_name FROM storage_b
ORDER BY item_name;

SELECT item_name FROM storage_a
UNION ALL
SELECT item_name FROM storage_b
ORDER BY item_name;

-- Out-of-stock items present in both storage locations.
SELECT item_id FROM storage_a WHERE quantity = 0
INTERSECT
SELECT item_id FROM storage_b WHERE quantity = 0;

-- Items only in storage A.
SELECT item_name FROM storage_a
EXCEPT
SELECT item_name FROM storage_b;

-- 8. Salary rankings: tied values distinguish ROW_NUMBER, RANK and DENSE_RANK.
SELECT staff_id, first_name, team_name, monthly_pay,
       ROW_NUMBER() OVER (PARTITION BY team_name ORDER BY monthly_pay DESC, staff_id) AS row_number,
       RANK() OVER (PARTITION BY team_name ORDER BY monthly_pay DESC) AS pay_rank,
       DENSE_RANK() OVER (PARTITION BY team_name ORDER BY monthly_pay DESC) AS dense_pay_rank
FROM staff
ORDER BY team_name, monthly_pay DESC, staff_id;

-- 9. Window aggregates, FILTER, LAG/LEAD and explicit running-total frame.
SELECT staff_id, first_name, team_name,
       monthly_pay,
       SUM(monthly_pay) OVER (PARTITION BY team_name) AS team_payroll,
       ROUND(AVG(monthly_pay) FILTER (WHERE experience_years > 5) OVER (), 2)
           AS experienced_staff_average,
       LAG(monthly_pay) OVER (ORDER BY staff_id) AS previous_pay,
       LEAD(monthly_pay) OVER (ORDER BY staff_id) AS next_pay,
       SUM(monthly_pay) OVER (
           ORDER BY staff_id
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS running_payroll
FROM staff
ORDER BY staff_id;

-- 10. Pivot and unpivot participation metrics.
CREATE TABLE annual_participation (
    program_name TEXT NOT NULL,
    report_year INTEGER NOT NULL,
    participant_count INTEGER NOT NULL CHECK (participant_count >= 0),
    PRIMARY KEY (program_name, report_year)
);
INSERT INTO annual_participation VALUES
    ('Digital Skills', 2024, 40), ('Digital Skills', 2025, 65), ('Digital Skills', 2026, 90),
    ('Leadership Lab', 2024, 30), ('Leadership Lab', 2025, 45), ('Leadership Lab', 2026, 60);

CREATE VIEW pivoted_participation AS
SELECT program_name,
       SUM(CASE WHEN report_year = 2024 THEN participant_count ELSE 0 END) AS year_2024,
       SUM(CASE WHEN report_year = 2025 THEN participant_count ELSE 0 END) AS year_2025,
       SUM(CASE WHEN report_year = 2026 THEN participant_count ELSE 0 END) AS year_2026
FROM annual_participation
GROUP BY program_name;

SELECT * FROM pivoted_participation ORDER BY program_name;

SELECT program_name, 2024 AS report_year, year_2024 AS participant_count
FROM pivoted_participation
UNION ALL
SELECT program_name, 2025 AS report_year, year_2025 AS participant_count
FROM pivoted_participation
UNION ALL
SELECT program_name, 2026 AS report_year, year_2026 AS participant_count
FROM pivoted_participation
ORDER BY program_name, report_year;

-- 11. Custom priority ordering with CASE.
CREATE TABLE program_tasks (
    task_name TEXT NOT NULL,
    priority TEXT NOT NULL CHECK (priority IN ('High', 'Medium', 'Low'))
);
INSERT INTO program_tasks VALUES
    ('Venue accessibility review', 'Medium'),
    ('Safeguarding briefing', 'High'),
    ('Newsletter formatting', 'Low');
SELECT task_name, priority
FROM program_tasks
ORDER BY CASE priority
            WHEN 'High' THEN 1
            WHEN 'Medium' THEN 2
            WHEN 'Low' THEN 3
            ELSE 4
         END, task_name;

-- 12. Query planning and index demonstration.
CREATE INDEX idx_lab15_staff_team_pay ON staff(team_name, monthly_pay);
ANALYZE staff;
EXPLAIN
SELECT first_name, monthly_pay
FROM staff
WHERE team_name = 'Media' AND monthly_pay > 65000;

-- EXPLAIN ANALYZE really runs this read-only SELECT. Timings and plan vary by machine.
EXPLAIN (ANALYZE, BUFFERS)
SELECT first_name, monthly_pay
FROM staff
WHERE team_name = 'Media' AND monthly_pay > 65000
ORDER BY monthly_pay DESC, staff_id
LIMIT 10;

RESET search_path;
