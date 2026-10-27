-- Lab 16 - Transactions and ACID Properties
-- Aizirek Myrzabayeva | Database Systems
-- Fictional learning-center budget and equipment transactions
-- This script is run ONLY against a temporary, isolated PostgreSQL cluster.

CREATE TABLE wallets (
    wallet_id INTEGER PRIMARY KEY,
    description TEXT NOT NULL,
    balance NUMERIC(12,2) NOT NULL CHECK (balance >= 0)
);
INSERT INTO wallets VALUES
    (1, 'Digital Learning Budget', 1000.00),
    (2, 'Community Outreach Budget', 1000.00);

CREATE TABLE participants (
    participant_id INTEGER PRIMARY KEY,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE
);
INSERT INTO participants VALUES (1, 'Adina Bekova', 'adina@example.org');

CREATE TABLE equipment (
    equipment_id INTEGER PRIMARY KEY,
    equipment_name TEXT NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0)
);
INSERT INTO equipment VALUES (101, 'Presentation Kit', 100.00);

CREATE TABLE inventory (
    equipment_id INTEGER PRIMARY KEY REFERENCES equipment(equipment_id),
    units_available INTEGER NOT NULL CHECK (units_available >= 0)
);
INSERT INTO inventory VALUES (101, 10);

CREATE TABLE reservations (
    reservation_id INTEGER PRIMARY KEY,
    participant_id INTEGER NOT NULL REFERENCES participants(participant_id),
    total_cost NUMERIC(10,2) NOT NULL CHECK (total_cost >= 0)
);
CREATE TABLE reservation_items (
    reservation_id INTEGER NOT NULL REFERENCES reservations(reservation_id),
    equipment_id INTEGER NOT NULL REFERENCES equipment(equipment_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (reservation_id, equipment_id)
);

CREATE TABLE activity_logs (message TEXT NOT NULL);
CREATE TABLE users (user_id INTEGER PRIMARY KEY, full_name TEXT NOT NULL);
CREATE TABLE user_preferences (
    user_id INTEGER PRIMARY KEY REFERENCES users(user_id),
    theme TEXT NOT NULL
);
CREATE TABLE audit_log (
    action TEXT NOT NULL,
    logged_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE facilitators_on_duty (
    facilitator_id INTEGER PRIMARY KEY,
    on_duty BOOLEAN NOT NULL
);
INSERT INTO facilitators_on_duty VALUES (1, true), (2, true);

CREATE OR REPLACE FUNCTION transfer_budget(
    sender_id INTEGER, recipient_id INTEGER, transfer_amount NUMERIC
) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    IF transfer_amount IS NULL OR transfer_amount <= 0 OR sender_id = recipient_id THEN
        RAISE EXCEPTION 'Invalid transfer parameters';
    END IF;
    -- Use a stable locking order to lower deadlock risk.
    PERFORM wallet_id FROM wallets
      WHERE wallet_id IN (sender_id, recipient_id)
      ORDER BY wallet_id FOR UPDATE;
    IF (SELECT count(*) FROM wallets WHERE wallet_id IN (sender_id, recipient_id)) <> 2 THEN
        RAISE EXCEPTION 'Budget wallet not found';
    END IF;
    IF (SELECT balance FROM wallets WHERE wallet_id = sender_id) < transfer_amount THEN
        RAISE EXCEPTION 'Insufficient budget';
    END IF;
    UPDATE wallets SET balance = balance - transfer_amount WHERE wallet_id = sender_id;
    UPDATE wallets SET balance = balance + transfer_amount WHERE wallet_id = recipient_id;
END;
$$;
