-- Laboratory Work 04 — First SQL Query
-- Student: Aizirek Myrzabayeva
-- PostgreSQL 18.6 (macOS)
-- Continues the Campus Events dataset created in Lab 03.
-- Run from the repository root:
-- psql -X -a -v ON_ERROR_STOP=1 -P pager=off -d postgres -f lab-04/lab04.sql
-- The script only reads data; it does not create, update, or delete anything.

-- 1. Display every column and event (4 rows).
SELECT *
FROM lab03.campus_events
ORDER BY event_id;

-- 2. Choose two columns and sort event titles alphabetically.
SELECT event_title, location
FROM lab03.campus_events
ORDER BY event_title ASC;

-- 3. Retrieve two fields from each event.
SELECT event_id, capacity
FROM lab03.campus_events
ORDER BY event_id;

-- 4. Find a specific event by its title (1 row).
SELECT event_title, location, capacity
FROM lab03.campus_events
WHERE event_title = 'Student Coding Circle';

-- 5. Filter events with at least 25 available places (2 rows).
SELECT event_title, location, capacity
FROM lab03.campus_events
WHERE capacity >= 25
ORDER BY capacity DESC;

-- 6. Sort event titles in reverse alphabetical order.
SELECT event_title, location
FROM lab03.campus_events
ORDER BY event_title DESC;

-- 7. Return the first two events in ID order (2 rows).
SELECT event_id, event_title
FROM lab03.campus_events
ORDER BY event_id
LIMIT 2;

-- 8. Show the three smallest events by capacity (3 rows).
SELECT event_title, capacity, location
FROM lab03.campus_events
ORDER BY capacity ASC, event_title ASC
LIMIT 3;

/* SQL comments explain each query and are ignored by PostgreSQL. */
