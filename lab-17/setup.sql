-- Lab 17: Data Import, Export and Backup
-- Aizirek Myrzabayeva | Fictional Community Media Studio
-- Execute ONLY against the isolated temporary PostgreSQL cluster created by demo.py.
-- This file contains no DROP DATABASE or filesystem operations.

CREATE TABLE public.programs (
    program_id INTEGER PRIMARY KEY,
    program_name TEXT NOT NULL UNIQUE
);
INSERT INTO public.programs VALUES (10, 'Digital Storytelling'), (20, 'Python Basics');

CREATE TABLE public.participants (
    participant_id INTEGER PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT,
    program_id INTEGER NOT NULL REFERENCES public.programs(program_id),
    joined_on DATE NOT NULL,
    CONSTRAINT unique_participant_email UNIQUE(email)
);
INSERT INTO public.participants VALUES
 (1, 'Amina', 'Kadyrova', 'amina@example.org', 10, DATE '2026-05-10'),
 (2, 'Айпери', 'Abdyldaeva', NULL, 20, DATE '2026-06-02'),
 (3, 'Murat', 'Tologonov', 'murat@example.org', 10, DATE '2026-07-14');

CREATE VIEW public.digital_participants AS
 SELECT participant_id, first_name, last_name
 FROM public.participants WHERE program_id = 10;

CREATE TABLE public.feedback (
    feedback_id INTEGER PRIMARY KEY,
    message TEXT NOT NULL
);
INSERT INTO public.feedback VALUES
 (1, 'Excellent, "really excellent"'),
 (2, E'First line\nSecond line'),
 (3, 'UTF-8: Ысык-Көл');

CREATE TABLE public.products (
    product_id INTEGER PRIMARY KEY,
    product_name TEXT NOT NULL,
    price NUMERIC(10,2) NOT NULL CHECK (price >= 0)
);
INSERT INTO public.products VALUES (1, 'USB microphone', 35.00), (2, 'Tripod', 18.50);

CREATE TABLE public.recovery_items (
    item_id INTEGER PRIMARY KEY,
    label TEXT NOT NULL
);
INSERT INTO public.recovery_items VALUES (1, 'Initial record');

CREATE TABLE public.daily_log (log_id INTEGER PRIMARY KEY, description TEXT);
INSERT INTO public.daily_log VALUES (1, 'A disposable record');

CREATE TABLE public.sales (
    sale_id INTEGER NOT NULL,
    sold_on DATE NOT NULL,
    amount NUMERIC(10,2) NOT NULL
) PARTITION BY RANGE (sold_on);
CREATE TABLE public.sales_2025 PARTITION OF public.sales FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE public.sales_2026 PARTITION OF public.sales FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
INSERT INTO public.sales VALUES (1, DATE '2025-08-04', 150.00), (2, DATE '2026-09-12', 220.00);

CREATE ROLE lab17_reader;
GRANT SELECT ON public.participants TO lab17_reader;
