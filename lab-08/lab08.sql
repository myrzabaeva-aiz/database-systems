-- Lab 08: Foreign Keys and Relationships
-- Aizirek Myrzabayeva | Database Systems
-- Fictional example: Community Workshop Network
-- WARNING: Running this file RESETS ONLY schema lab08 and its contents.
-- Other laboratory schemas and databases are not modified.

BEGIN;
DROP SCHEMA IF EXISTS lab08 CASCADE;
CREATE SCHEMA lab08;

-- ================================================================
-- Part A: Foreign keys and referential actions
-- ================================================================
CREATE TABLE lab08.divisions (
    division_id INTEGER PRIMARY KEY,
    division_name VARCHAR(70) NOT NULL UNIQUE
);
INSERT INTO lab08.divisions VALUES
    (0, 'Unassigned'),
    (10, 'Planning'),
    (20, 'Media Production'),
    (30, 'Outreach'),
    (40, 'Participant Support'),
    (50, 'Evaluation'),
    (60, 'Program Delivery');

-- Method 1: inline FOREIGN KEY + ON DELETE RESTRICT.
CREATE TABLE lab08.restrict_members (
    member_id INTEGER PRIMARY KEY,
    division_id INTEGER NOT NULL REFERENCES lab08.divisions(division_id)
        ON DELETE RESTRICT
);

-- Method 2: table-level FOREIGN KEY + ON DELETE CASCADE.
CREATE TABLE lab08.cascade_members (
    member_id INTEGER PRIMARY KEY,
    division_id INTEGER NOT NULL,
    FOREIGN KEY (division_id) REFERENCES lab08.divisions(division_id)
        ON DELETE CASCADE
);

-- Method 3: named FOREIGN KEY + ON DELETE SET NULL.
CREATE TABLE lab08.nullable_members (
    member_id INTEGER PRIMARY KEY,
    division_id INTEGER,
    CONSTRAINT fk_nullable_member_division FOREIGN KEY (division_id)
        REFERENCES lab08.divisions(division_id) ON DELETE SET NULL
);

-- Method 4: add a FOREIGN KEY using ALTER TABLE + SET DEFAULT.
CREATE TABLE lab08.default_members (
    member_id INTEGER PRIMARY KEY,
    division_id INTEGER NOT NULL DEFAULT 0
);
ALTER TABLE lab08.default_members
    ADD CONSTRAINT fk_default_member_division
    FOREIGN KEY (division_id) REFERENCES lab08.divisions(division_id)
    ON DELETE SET DEFAULT;

-- ON UPDATE CASCADE propagates a changed parent ID to the child.
CREATE TABLE lab08.update_members (
    member_id INTEGER PRIMARY KEY,
    division_id INTEGER NOT NULL REFERENCES lab08.divisions(division_id)
        ON UPDATE CASCADE
);

-- Combined ON UPDATE / ON DELETE CASCADE.
CREATE TABLE lab08.combined_members (
    member_id INTEGER PRIMARY KEY,
    division_id INTEGER NOT NULL REFERENCES lab08.divisions(division_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

INSERT INTO lab08.restrict_members VALUES (101, 10);
INSERT INTO lab08.cascade_members VALUES (102, 20);
INSERT INTO lab08.nullable_members VALUES (103, 30);
INSERT INTO lab08.default_members VALUES (104, 40);
INSERT INTO lab08.update_members VALUES (105, 50);
INSERT INTO lab08.combined_members VALUES (106, 60);

-- Negative tests are caught intentionally, so the script can finish.
DO $$
BEGIN
    BEGIN
        INSERT INTO lab08.restrict_members VALUES (999, 999);
        RAISE EXCEPTION 'FAIL: invalid division INSERT was accepted';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'PASS: invalid foreign key on INSERT rejected';
    END;

    BEGIN
        UPDATE lab08.restrict_members SET division_id = 999 WHERE member_id = 101;
        RAISE EXCEPTION 'FAIL: invalid division UPDATE was accepted';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'PASS: invalid foreign key on UPDATE rejected';
    END;

    BEGIN
        DELETE FROM lab08.divisions WHERE division_id = 10;
        RAISE EXCEPTION 'FAIL: ON DELETE RESTRICT did not protect parent';
    EXCEPTION WHEN restrict_violation OR foreign_key_violation THEN
        RAISE NOTICE 'PASS: RESTRICT prevented deletion of referenced parent';
    END;
END $$;

-- These three parent deletions invoke distinct actions.
DELETE FROM lab08.divisions WHERE division_id IN (20, 30, 40);
-- Change parent IDs: the children must track these updates.
UPDATE lab08.divisions SET division_id = 55 WHERE division_id = 50;
UPDATE lab08.divisions SET division_id = 66 WHERE division_id = 60;
SELECT member_id, division_id FROM lab08.combined_members ORDER BY member_id;
DELETE FROM lab08.divisions WHERE division_id = 66;

SELECT 'RESTRICT: kept' AS test, COUNT(*) AS matching_rows
FROM lab08.divisions WHERE division_id = 10
UNION ALL SELECT 'CASCADE: removed', COUNT(*) FROM lab08.cascade_members
UNION ALL SELECT 'SET NULL: null', COUNT(*) FROM lab08.nullable_members WHERE division_id IS NULL
UNION ALL SELECT 'SET DEFAULT: 0', COUNT(*) FROM lab08.default_members WHERE division_id = 0
UNION ALL SELECT 'UPDATE CASCADE: 55', COUNT(*) FROM lab08.update_members WHERE division_id = 55
UNION ALL SELECT 'BOTH CASCADE: removed', COUNT(*) FROM lab08.combined_members;

-- ================================================================
-- Part B: One-to-one relationships (two valid designs)
-- ================================================================
CREATE TABLE lab08.accounts (
    account_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username VARCHAR(60) NOT NULL UNIQUE
);

-- Shared primary key is also a foreign key.
CREATE TABLE lab08.account_profiles (
    account_id INTEGER PRIMARY KEY REFERENCES lab08.accounts(account_id)
        ON DELETE CASCADE,
    bio TEXT
);

-- Alternatively, a separate primary key and a UNIQUE NOT NULL FK.
CREATE TABLE lab08.account_contact_cards (
    card_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id INTEGER NOT NULL UNIQUE REFERENCES lab08.accounts(account_id)
        ON DELETE CASCADE,
    contact_note VARCHAR(80)
);

INSERT INTO lab08.accounts (username) VALUES
    ('amina.community'), ('bekzat.community');
INSERT INTO lab08.account_profiles VALUES (1, 'Workshop participant');
INSERT INTO lab08.account_contact_cards (account_id, contact_note)
    VALUES (1, 'Email notifications enabled');

DO $$
BEGIN
    BEGIN
        INSERT INTO lab08.account_profiles VALUES (1, 'Second profile');
        RAISE EXCEPTION 'FAIL: duplicate shared primary key accepted';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'PASS: shared primary key rejected duplicate profile';
    END;

    BEGIN
        INSERT INTO lab08.account_contact_cards (account_id, contact_note)
        VALUES (1, 'Duplicate contact card');
        RAISE EXCEPTION 'FAIL: duplicate UNIQUE foreign key accepted';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'PASS: UNIQUE foreign key rejected duplicate contact card';
    END;
END $$;

SELECT a.username, p.bio, c.contact_note
FROM lab08.accounts AS a
LEFT JOIN lab08.account_profiles AS p USING (account_id)
LEFT JOIN lab08.account_contact_cards AS c USING (account_id)
ORDER BY a.account_id;

-- ================================================================
-- Part C: One-to-many (facilitator -> workshop sessions)
-- ================================================================
CREATE TABLE lab08.facilitators (
    facilitator_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL
);
CREATE TABLE lab08.workshop_sessions (
    session_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    session_code VARCHAR(20) NOT NULL UNIQUE,
    topic VARCHAR(100) NOT NULL,
    facilitator_id INTEGER NOT NULL REFERENCES lab08.facilitators(facilitator_id)
);
INSERT INTO lab08.facilitators (full_name) VALUES ('Ayla Temirova');
INSERT INTO lab08.workshop_sessions (session_code, topic, facilitator_id) VALUES
    ('DS101', 'Digital Citizenship', 1),
    ('PY120', 'Python for Beginners', 1);
SELECT f.full_name AS facilitator, s.session_code, s.topic
FROM lab08.facilitators AS f
JOIN lab08.workshop_sessions AS s USING (facilitator_id)
ORDER BY s.session_code;

-- ================================================================
-- Part D: Many-to-many via junction table
-- ================================================================
CREATE TABLE lab08.participants (
    participant_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(120) NOT NULL UNIQUE
);
INSERT INTO lab08.participants (full_name, email) VALUES
    ('Amina Taylakova', 'amina.taylakova@example.org'),
    ('Rayan Nurmatov', 'rayan.nurmatov@example.org');

CREATE TABLE lab08.workshop_registrations (
    participant_id INTEGER NOT NULL REFERENCES lab08.participants(participant_id)
        ON DELETE CASCADE,
    session_id INTEGER NOT NULL REFERENCES lab08.workshop_sessions(session_id)
        ON DELETE CASCADE,
    registration_status VARCHAR(20) NOT NULL DEFAULT 'Confirmed',
    PRIMARY KEY (participant_id, session_id)
);
INSERT INTO lab08.workshop_registrations
    (participant_id, session_id, registration_status) VALUES
    (1, 1, 'Confirmed'),
    (1, 2, 'Confirmed'),
    (2, 1, 'Waitlisted');

DO $$
BEGIN
    BEGIN
        INSERT INTO lab08.workshop_registrations
            (participant_id, session_id) VALUES (1, 1);
        RAISE EXCEPTION 'FAIL: duplicate workshop registration accepted';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'PASS: composite primary key rejected duplicate registration';
    END;

    BEGIN
        INSERT INTO lab08.workshop_registrations
            (participant_id, session_id) VALUES (999, 1);
        RAISE EXCEPTION 'FAIL: registration for unknown participant accepted';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'PASS: registration rejected unknown participant';
    END;
END $$;

-- All registrations (3 rows).
SELECT p.full_name AS participant, s.session_code, r.registration_status
FROM lab08.workshop_registrations AS r
JOIN lab08.participants AS p USING (participant_id)
JOIN lab08.workshop_sessions AS s USING (session_id)
ORDER BY p.full_name, s.session_code;

-- All participants in Digital Citizenship (2 rows).
SELECT p.full_name AS participant, r.registration_status
FROM lab08.workshop_registrations AS r
JOIN lab08.participants AS p USING (participant_id)
JOIN lab08.workshop_sessions AS s USING (session_id)
WHERE s.session_code = 'DS101'
ORDER BY p.full_name;

-- Sessions taken by Amina (2 rows).
SELECT s.session_code, s.topic, r.registration_status
FROM lab08.workshop_registrations AS r
JOIN lab08.participants AS p USING (participant_id)
JOIN lab08.workshop_sessions AS s USING (session_id)
WHERE p.email = 'amina.taylakova@example.org'
ORDER BY s.session_code;

-- PostgreSQL system catalog: inspect FK definitions.
SELECT conname AS constraint_name, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE connamespace = 'lab08'::regnamespace AND contype = 'f'
ORDER BY conname;

COMMIT;

-- These psql meta-commands show the final relationship definitions.
\d lab08.workshop_registrations
\d lab08.account_profiles
\d lab08.account_contact_cards
\d lab08.combined_members
\d lab08.default_members
