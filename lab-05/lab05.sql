\set ON_ERROR_STOP on
\pset pager off

-- Lab 05: Databases
-- Student: Aizirek Myrzabayeva
-- Run while connected to the 'postgres' maintenance database.
-- Keep the permanent database; remove only our temporary demo database.

-- 1. Create a personal practice database only if it does not already exist.
SELECT format('CREATE DATABASE %I', 'aizirek_lab05')
WHERE NOT EXISTS (
    SELECT 1 FROM pg_database WHERE datname = 'aizirek_lab05'
)
\gexec

-- 2. Create a unique disposable database, then delete that same database.
-- A new backend PID gives each session a distinct demonstration name.
SELECT 'aizirek_lab05_demo_' || pg_backend_pid() AS demo_db
\gset

\echo Creating temporary demonstration database :demo_db
CREATE DATABASE :"demo_db";

\echo Removing temporary demonstration database :demo_db
DROP DATABASE :"demo_db";

-- Confirm that only the temporary demo was removed (expect 0 rows).
SELECT datname AS remaining_demo_database
FROM pg_database
WHERE datname = :'demo_db';

-- 3. List the permanent database, then connect to it.
\l aizirek_lab05
\connect aizirek_lab05

-- 4. Verify the active database and user.
SELECT current_database() AS connected_database,
       current_user AS connected_user;

\conninfo
