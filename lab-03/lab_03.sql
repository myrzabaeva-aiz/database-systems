-- Lab 03: Basic psql Commands (SQL sample used for inspection)
-- Student: Aizirek Myrzabayeva
-- Sample: Campus Events, all entries are fictional.
-- PostgreSQL 18; execute from the repository root using:
-- psql -d postgres -v ON_ERROR_STOP=1 -f lab-03/lab_03.sql

CREATE SCHEMA IF NOT EXISTS lab03;

CREATE TABLE IF NOT EXISTS lab03.campus_events (
    event_id INTEGER PRIMARY KEY,
    event_title VARCHAR(100) NOT NULL,
    location VARCHAR(80) NOT NULL,
    capacity INTEGER NOT NULL CHECK (capacity > 0)
);

INSERT INTO lab03.campus_events (event_id, event_title, location, capacity)
VALUES
    (401, 'Research Poster Workshop', 'Innovation Studio', 28),
    (402, 'Student Coding Circle', 'Computer Lab B', 24),
    (403, 'Design Thinking Session', 'Collaboration Room', 35),
    (404, 'Digital Storytelling Meetup', 'Media Space', 20)
ON CONFLICT (event_id) DO UPDATE SET
    event_title = EXCLUDED.event_title,
    location = EXCLUDED.location,
    capacity = EXCLUDED.capacity;

SELECT event_id, event_title, location, capacity
FROM lab03.campus_events
ORDER BY event_id;
