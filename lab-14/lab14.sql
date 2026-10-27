-- Lab 14: Joining Tables
-- Student: Aizirek Myrzabayeva | Database Systems
-- Fictional project: Community Equipment & Workshops
-- WARNING: running this script replaces ONLY the lab14 schema.

BEGIN;
DROP SCHEMA IF EXISTS lab14 CASCADE;
CREATE SCHEMA lab14;
SET LOCAL search_path TO lab14, pg_catalog;

-- Part 1: Partners, requests, and five types of joins.
CREATE TABLE partner_organizations (
    partner_id INTEGER PRIMARY KEY,
    organization_name VARCHAR(100) NOT NULL UNIQUE,
    contact_email VARCHAR(120) NOT NULL
);

CREATE TABLE supply_requests (
    request_id INTEGER PRIMARY KEY,
    partner_id INTEGER REFERENCES partner_organizations(partner_id),
    requested_on DATE NOT NULL,
    estimated_cost NUMERIC(10,2) NOT NULL CHECK (estimated_cost >= 0)
);

INSERT INTO partner_organizations VALUES
    (1, 'Mountain Makers', 'hello@mountain.example'),
    (2, 'Learning Bridge', 'team@bridge.example'),
    (3, 'Sunrise Network', 'info@sunrise.example');

-- Request 104 is a guest request: partner_id IS NULL.
-- Sunrise Network has no requests.
INSERT INTO supply_requests VALUES
    (101, 1, DATE '2026-09-11', 250.00),
    (102, 1, DATE '2026-09-12', 70.00),
    (103, 2, DATE '2026-09-13', 270.00),
    (104, NULL, DATE '2026-09-14', 35.00);

-- INNER JOIN: only the three matched requests.
SELECT p.organization_name, r.request_id, r.estimated_cost
FROM partner_organizations AS p
INNER JOIN supply_requests AS r ON r.partner_id = p.partner_id
ORDER BY r.request_id;

-- LEFT JOIN: keep the partner without a request (4 rows).
SELECT p.organization_name, r.request_id
FROM partner_organizations AS p
LEFT JOIN supply_requests AS r ON r.partner_id = p.partner_id
ORDER BY p.partner_id, r.request_id NULLS LAST;

-- RIGHT JOIN: keep all requests, including guest request 104 (4 rows).
SELECT p.organization_name, r.request_id
FROM partner_organizations AS p
RIGHT JOIN supply_requests AS r ON r.partner_id = p.partner_id
ORDER BY r.request_id;

-- FULL OUTER JOIN: unmatched partner + guest request (5 rows).
SELECT p.organization_name, r.request_id, r.estimated_cost
FROM partner_organizations AS p
FULL OUTER JOIN supply_requests AS r ON r.partner_id = p.partner_id
ORDER BY p.partner_id NULLS LAST, r.request_id NULLS LAST;

-- CROSS JOIN: 3 partner organizations x 2 items = 6 rows.
CREATE TABLE equipment_catalog (
    equipment_id INTEGER PRIMARY KEY,
    item_name VARCHAR(80) NOT NULL,
    unit_cost NUMERIC(10,2) NOT NULL CHECK (unit_cost >= 0)
);
INSERT INTO equipment_catalog VALUES
    (11, 'Portable Microphone', 35.00),
    (12, 'Training Tablet', 90.00);

SELECT p.organization_name, e.item_name
FROM partner_organizations AS p
CROSS JOIN equipment_catalog AS e
ORDER BY p.partner_id, e.equipment_id;

-- Part 2: Four-table join across parent and junction tables.
CREATE TABLE request_items (
    request_id INTEGER NOT NULL REFERENCES supply_requests(request_id),
    equipment_id INTEGER NOT NULL REFERENCES equipment_catalog(equipment_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (request_id, equipment_id)
);
INSERT INTO request_items VALUES
    (101, 11, 2), (101, 12, 2),
    (102, 11, 2),
    (103, 12, 3),
    (104, 11, 1);

-- Four tables: guest request has no partner and is excluded by INNER JOIN.
SELECT p.organization_name, r.request_id,
       e.item_name, ri.quantity, e.unit_cost,
       ri.quantity * e.unit_cost AS item_total
FROM partner_organizations AS p
JOIN supply_requests AS r ON r.partner_id = p.partner_id
JOIN request_items AS ri ON ri.request_id = r.request_id
JOIN equipment_catalog AS e ON e.equipment_id = ri.equipment_id
ORDER BY r.request_id, e.equipment_id;

-- Part 3: Self join for reporting structure.
CREATE TABLE team_members (
    member_id INTEGER PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    supervisor_id INTEGER REFERENCES team_members(member_id)
);
INSERT INTO team_members VALUES
    (1, 'Program Director', NULL),
    (2, 'Logistics Coordinator', 1),
    (3, 'Workshop Assistant', 2);

SELECT worker.full_name AS team_member,
       supervisor.full_name AS supervisor
FROM team_members AS worker
LEFT JOIN team_members AS supervisor
    ON supervisor.member_id = worker.supervisor_id
ORDER BY worker.member_id;

-- Part 4: Join with conditions.
SELECT p.organization_name, r.request_id, r.requested_on, r.estimated_cost
FROM partner_organizations AS p
JOIN supply_requests AS r ON r.partner_id = p.partner_id
WHERE r.requested_on >= DATE '2026-09-11'
  AND r.estimated_cost > 100
ORDER BY r.request_id;

-- Part 5: One-to-one relation: nullable LEFT JOIN preserves unmatched partners.
CREATE TABLE partner_profiles (
    partner_id INTEGER PRIMARY KEY
        REFERENCES partner_organizations(partner_id) ON DELETE CASCADE,
    preferred_contact VARCHAR(60) NOT NULL
);
INSERT INTO partner_profiles VALUES (1, 'Email updates');

SELECT p.organization_name, pr.preferred_contact
FROM partner_organizations AS p
LEFT JOIN partner_profiles AS pr USING (partner_id)
ORDER BY p.partner_id;

-- Part 6: One-to-many relation: one trainer leads two workshop sessions.
CREATE TABLE trainers (
    trainer_id INTEGER PRIMARY KEY,
    trainer_name VARCHAR(100) NOT NULL
);
CREATE TABLE training_sessions (
    session_id INTEGER PRIMARY KEY,
    session_code VARCHAR(20) NOT NULL UNIQUE,
    topic VARCHAR(100) NOT NULL,
    trainer_id INTEGER NOT NULL REFERENCES trainers(trainer_id)
);
INSERT INTO trainers VALUES (1, 'Ayla Temirova');
INSERT INTO training_sessions VALUES
    (201, 'DIG-101', 'Digital Safety', 1),
    (202, 'WEB-110', 'Building a Web Page', 1);

SELECT t.trainer_name, s.session_code, s.topic
FROM trainers AS t
JOIN training_sessions AS s USING (trainer_id)
ORDER BY s.session_id;

-- Part 7: Many-to-many volunteers to community projects via junction table.
CREATE TABLE volunteers (
    volunteer_id INTEGER PRIMARY KEY,
    volunteer_name VARCHAR(100) NOT NULL
);
CREATE TABLE community_projects (
    project_id INTEGER PRIMARY KEY,
    project_title VARCHAR(100) NOT NULL
);
CREATE TABLE project_assignments (
    volunteer_id INTEGER NOT NULL REFERENCES volunteers(volunteer_id),
    project_id INTEGER NOT NULL REFERENCES community_projects(project_id),
    assignment_role VARCHAR(60) NOT NULL,
    PRIMARY KEY (volunteer_id, project_id)
);
INSERT INTO volunteers VALUES (501, 'Mira Alieva'), (502, 'Timur Akylov');
INSERT INTO community_projects VALUES
    (701, 'Neighborhood Technology Day'),
    (702, 'Community Reading Circle');
INSERT INTO project_assignments VALUES
    (501, 701, 'Coordinator'),
    (501, 702, 'Facilitator'),
    (502, 701, 'Volunteer');

SELECT v.volunteer_name, p.project_title, a.assignment_role
FROM volunteers AS v
JOIN project_assignments AS a USING (volunteer_id)
JOIN community_projects AS p USING (project_id)
ORDER BY v.volunteer_id, p.project_id;

-- Part 8: Find unmatched partners and guest requests using NULL tests.
SELECT p.organization_name AS partner_without_requests
FROM partner_organizations AS p
LEFT JOIN supply_requests AS r USING (partner_id)
WHERE r.request_id IS NULL;

SELECT r.request_id AS guest_request
FROM partner_organizations AS p
RIGHT JOIN supply_requests AS r USING (partner_id)
WHERE p.partner_id IS NULL;

-- Part 9: Indexes and real plan (implementation varies across machines).
CREATE INDEX idx_supply_requests_partner_id ON supply_requests(partner_id);
CREATE INDEX idx_request_items_equipment_id ON request_items(equipment_id);

EXPLAIN (ANALYZE, BUFFERS)
SELECT p.organization_name, r.request_id
FROM partner_organizations AS p
JOIN supply_requests AS r ON r.partner_id = p.partner_id;

COMMIT;
