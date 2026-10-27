-- Lab 09: Database Design Basics
-- Student: Aizirek Myrzabayeva
-- Example: Fictional Community Film Festival
-- WARNING: Re-running this file replaces only the lab09 schema and its contents.

BEGIN;
DROP SCHEMA IF EXISTS lab09 CASCADE;
CREATE SCHEMA lab09;

-- A person's birth date is stored; age can be derived when needed.
CREATE TABLE lab09.filmmakers (
    filmmaker_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(60) NOT NULL,
    last_name VARCHAR(60) NOT NULL,
    email VARCHAR(120) NOT NULL UNIQUE,
    birth_date DATE NOT NULL,
    hometown VARCHAR(70) NOT NULL
);

-- 1NF: each phone number is a separate row, not a comma-separated field.
CREATE TABLE lab09.filmmaker_phones (
    filmmaker_id INTEGER NOT NULL REFERENCES lab09.filmmakers(filmmaker_id)
        ON DELETE CASCADE,
    phone_number VARCHAR(30) NOT NULL,
    phone_type VARCHAR(15) NOT NULL CHECK (phone_type IN ('mobile', 'home')),
    PRIMARY KEY (filmmaker_id, phone_number)
);

-- 3NF: category names are defined here instead of being repeated in films.
CREATE TABLE lab09.film_categories (
    category_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_name VARCHAR(70) NOT NULL UNIQUE,
    category_description TEXT
);

CREATE TABLE lab09.films (
    film_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    film_code VARCHAR(15) NOT NULL UNIQUE,
    title VARCHAR(160) NOT NULL,
    category_id INTEGER NOT NULL REFERENCES lab09.film_categories(category_id),
    release_year INTEGER NOT NULL CHECK (release_year BETWEEN 2000 AND 2100),
    duration_minutes INTEGER NOT NULL CHECK (duration_minutes BETWEEN 1 AND 180)
);

-- A many-to-many relationship represented by a junction table.
-- 2NF: film title and filmmaker name are stored in their own tables.
CREATE TABLE lab09.film_creators (
    film_id INTEGER NOT NULL REFERENCES lab09.films(film_id) ON DELETE CASCADE,
    filmmaker_id INTEGER NOT NULL REFERENCES lab09.filmmakers(filmmaker_id),
    contribution_role VARCHAR(20) NOT NULL
        CHECK (contribution_role IN ('Director', 'Co-director', 'Producer')),
    PRIMARY KEY (film_id, filmmaker_id)
);

-- Composite address: street, city, and postal code stored separately.
CREATE TABLE lab09.venues (
    venue_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    venue_name VARCHAR(120) NOT NULL,
    street VARCHAR(120) NOT NULL,
    city VARCHAR(70) NOT NULL,
    postal_code VARCHAR(12) NOT NULL,
    capacity INTEGER NOT NULL CHECK (capacity > 0),
    UNIQUE (venue_name, city)
);

-- A film can have several screenings; each screening occurs at one venue.
CREATE TABLE lab09.screenings (
    screening_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    film_id INTEGER NOT NULL REFERENCES lab09.films(film_id),
    venue_id INTEGER NOT NULL REFERENCES lab09.venues(venue_id),
    starts_at TIMESTAMP NOT NULL,
    ticket_price NUMERIC(8, 2) NOT NULL DEFAULT 0 CHECK (ticket_price >= 0),
    screening_status VARCHAR(15) NOT NULL
        CHECK (screening_status IN ('Scheduled', 'Completed')),
    UNIQUE (film_id, venue_id, starts_at)
);

-- Indexes on foreign-key columns used in joins and schedule queries.
CREATE INDEX screenings_film_id_idx ON lab09.screenings (film_id);
CREATE INDEX screenings_venue_time_idx ON lab09.screenings (venue_id, starts_at);
CREATE INDEX film_creators_filmmaker_idx ON lab09.film_creators (filmmaker_id);

-- All names, emails, and numbers below are fictional demonstration data.
INSERT INTO lab09.filmmakers (first_name, last_name, email, birth_date, hometown) VALUES
    ('Elina', 'Maratova', 'elina.maratova@example.org', DATE '2004-06-19', 'Naryn'),
    ('Adilet', 'Jumabaev', 'adilet.jumabaev@example.org', DATE '2003-09-07', 'Osh'),
    ('Malika', 'Toktosunova', 'malika.toktosunova@example.org', DATE '2005-02-24', 'Karakol');

INSERT INTO lab09.filmmaker_phones (filmmaker_id, phone_number, phone_type) VALUES
    (1, 'DEMO-MOBILE-001', 'mobile'),
    (1, 'DEMO-HOME-001', 'home'),
    (2, 'DEMO-MOBILE-002', 'mobile');

INSERT INTO lab09.film_categories (category_name, category_description) VALUES
    ('Documentary', 'Stories inspired by real-world issues'),
    ('Short Fiction', 'Original scripted short narratives'),
    ('Animation', 'Animated storytelling');

INSERT INTO lab09.films (film_code, title, category_id, release_year, duration_minutes) VALUES
    ('FF-101', 'Voices Before Sunrise', 1, 2026, 11),
    ('FF-102', 'A Window to Tomorrow', 2, 2026, 9),
    ('FF-103', 'Paper Wings', 3, 2025, 7);

INSERT INTO lab09.film_creators (film_id, filmmaker_id, contribution_role) VALUES
    (1, 1, 'Director'),
    (1, 2, 'Co-director'),
    (2, 3, 'Director'),
    (3, 1, 'Director');

INSERT INTO lab09.venues (venue_name, street, city, postal_code, capacity) VALUES
    ('Riverside Cultural Hall', '18 Demo Street', 'Bishkek', '720000', 120),
    ('Youth Arts Space', '5 Example Avenue', 'Bishkek', '720001', 65);

INSERT INTO lab09.screenings (film_id, venue_id, starts_at, ticket_price, screening_status) VALUES
    (1, 1, TIMESTAMP '2026-11-14 14:00:00', 0.00, 'Scheduled'),
    (2, 2, TIMESTAMP '2026-11-14 16:00:00', 100.00, 'Scheduled'),
    (3, 1, TIMESTAMP '2026-11-15 11:30:00', 0.00, 'Scheduled');

COMMIT;

-- Film credits: 4 rows (one film has two filmmakers).
SELECT f.film_code, f.title AS film, c.category_name,
       m.first_name || ' ' || m.last_name AS filmmaker, fc.contribution_role
FROM lab09.films AS f
JOIN lab09.film_categories AS c ON c.category_id = f.category_id
JOIN lab09.film_creators AS fc ON fc.film_id = f.film_id
JOIN lab09.filmmakers AS m ON m.filmmaker_id = fc.filmmaker_id
ORDER BY f.film_code, filmmaker;

-- Venue screening schedule: 3 rows, including ticket prices.
SELECT f.title AS film, v.venue_name, v.city,
       s.starts_at, s.ticket_price, s.screening_status
FROM lab09.screenings AS s
JOIN lab09.films AS f ON f.film_id = s.film_id
JOIN lab09.venues AS v ON v.venue_id = s.venue_id
ORDER BY s.starts_at;

-- Multivalued attribute in 1NF: one phone number per row.
SELECT m.email, p.phone_number, p.phone_type
FROM lab09.filmmakers AS m
JOIN lab09.filmmaker_phones AS p USING (filmmaker_id)
ORDER BY m.email, p.phone_type;

-- Derived attribute: calculate age instead of storing a changing value.
SELECT first_name, last_name,
       EXTRACT(YEAR FROM AGE(CURRENT_DATE, birth_date))::INTEGER AS age_years
FROM lab09.filmmakers
ORDER BY filmmaker_id;
