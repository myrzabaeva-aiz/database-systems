CREATE TABLE students (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    age INT
);

INSERT INTO students (name, age)
VALUES ('Alice', 21), ('Bob', 23);

SELECT * FROM students;