-- Lab 10 — Viewing Database and Table Structure
-- Student: Aizirek Myrzabayeva
-- Inspect the Community Film Festival schema created in Lab 09.
-- Read-only: no tables are created, altered, or dropped.

-- 1. Tables belonging to Lab 09.
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'lab09' AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- 2. Four selected tables: fields, types, nullability, and defaults.
SELECT table_name, ordinal_position, column_name,
       data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'lab09'
  AND table_name IN ('filmmakers', 'films', 'film_creators', 'screenings')
ORDER BY table_name, ordinal_position;

-- 3. Primary keys, foreign keys, uniqueness, and CHECK rules.
SELECT c.conrelid::regclass AS table_name,
       c.conname AS constraint_name,
       CASE c.contype
           WHEN 'p' THEN 'PRIMARY KEY'
           WHEN 'f' THEN 'FOREIGN KEY'
           WHEN 'u' THEN 'UNIQUE'
           WHEN 'c' THEN 'CHECK'
       END AS constraint_type,
       pg_get_constraintdef(c.oid) AS definition
FROM pg_constraint AS c
JOIN pg_namespace AS n ON n.oid = c.connamespace
WHERE n.nspname = 'lab09'
  AND c.contype IN ('p', 'f', 'u', 'c')
ORDER BY c.conrelid::regclass::text, c.conname;

-- 4. Indexes created to support keys, constraints, and selected searches.
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'lab09'
  AND tablename IN ('filmmakers', 'films', 'film_creators', 'screenings')
ORDER BY tablename, indexname;

-- 5. Count actual schema objects. The original Lab 09 model has
--    seven tables and six foreign-key constraints.
SELECT
    (SELECT COUNT(*) FROM information_schema.tables
     WHERE table_schema = 'lab09' AND table_type = 'BASE TABLE') AS table_count,
    (SELECT COUNT(*) FROM pg_constraint AS c
     JOIN pg_namespace AS n ON n.oid = c.connamespace
     WHERE n.nspname = 'lab09' AND c.contype = 'f') AS foreign_key_count;
