CREATE TABLE students(
	student_id SERIAL PRIMARY KEY,
	name VARCHAR(100),
	email TEXT NOT NULL,
	faculty VARCHAR(100)
);

INSERT INTO students (name, email,faculty) VALUES ('Alymbek', 'alymbek@example.com', 'COMSEH'),
('Timur', 'timur@example.com', 'MED'),
('Beka', 'beka@example.com', 'MAT'),
('Aizrek', 'aizirek@example.com', 'SFW'),
('Alinur', 'alinur@example.com', 'SFW');


SELECT * FROM students;
SELECT name, email FROM students;
SELECT student_id, faculty FROM students;
SELECT name, email, faculty FROM students WHERE name ='Timur';
SELECT name, email FROM students ORDER BY name ASC ;
SELECT name, email FROM students LIMIT 2;


