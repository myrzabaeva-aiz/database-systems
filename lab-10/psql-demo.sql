\set ON_ERROR_STOP on
\pset pager off

-- Lab 10 assumes Lab 09 has already created the film festival tables.
DO $lab10_check$
BEGIN
    IF to_regclass('lab09.films') IS NULL
       OR to_regclass('lab09.film_creators') IS NULL
       OR to_regclass('lab09.screenings') IS NULL
       OR to_regclass('lab09.filmmakers') IS NULL THEN
        RAISE EXCEPTION 'Missing Lab 09 tables. Run zsh lab-09/capture_lab09.sh first, then rerun Lab 10.';
    END IF;
END
$lab10_check$;

-- psql meta-commands: table list and detailed table structure.
\dt lab09.*
\d lab09.filmmakers
\d lab09.films
\d lab09.film_creators
\d lab09.screenings

-- Query PostgreSQL metadata catalogs.
\ir lab10.sql
