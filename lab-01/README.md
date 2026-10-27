# Lab 01 — Introduction to Relational Databases

**Course:** Databases (COM-424.1) · American University of Central Asia  
**Student:** Aizirek Myrzabayeva · **Student ID:** 11036  
**Lab topic:** Introduction to Relational Databases  
**Type:** Conceptual study and relational data-model example

> **Scope:** This work addresses the *Lab 1 topic* in the course syllabus. It is not a PostgreSQL installation or SQL execution lab. The instructor's detailed Lab 1 handout has not been available for verification, so this document should be compared against that handout before final submission. The sample system and records below are fictional.

## 1. Overview

Most applications store more than one kind of information. A university equipment desk, for example, needs to know which devices are available, which students borrow them, and when items are due. Keeping all of these facts in one large spreadsheet seems easy initially, but it quickly produces repeated data and inconsistent records.

A **relational database** organizes information into multiple *related tables*. Each table describes an entity; uniquely identified records can be connected without copying every detail into each transaction. In this lab, I explain the fundamentals of the relational model and design a small **Campus Equipment Lending** example to show how the concepts work together.

## 2. Learning Objectives

By completing this introduction, I aim to:

1. Explain the difference between **data**, a **database**, and a **database management system (DBMS)**.
2. Recognize the parts of a relational table: **relations, tuples, attributes**, and their data types.
3. Distinguish **primary keys** from **foreign keys** and explain **referential integrity**.
4. Identify **one-to-many** and **many-to-many** relationships.
5. Understand how splitting data into related tables reduces redundancy.
6. Compare relational/SQL systems with non-relational/NoSQL approaches.
7. Describe the **ACID** properties of database transactions at a conceptual level.

## 3. Database Fundamentals

### 3.1 Data, database, DBMS and SQL

| Term | Meaning | Campus lending example |
| --- | --- | --- |
| **Data** | Individual facts, values, or observations. | An item name, student ID, or due date. |
| **Database** | An organized collection of related information. | A collection of student, equipment, and loan records. |
| **DBMS** | Software used to define, store, query, update, and manage databases. | PostgreSQL. |
| **RDBMS** | A DBMS implementing a relational data model. | PostgreSQL, MySQL, SQLite. |
| **SQL** | Structured Query Language, commonly used for defining and querying relational databases. | `SELECT`, `CREATE TABLE`, `INSERT`. |

**Key distinction:** PostgreSQL is software, SQL is a language, and the relational model is a way to organize information. They are related, but they are not interchangeable terms.

### 3.2 What does a relational table contain?

Consider the following *fictional* `students` relation:

| student_id | student_name | program |
| ---: | --- | --- |
| 501 | Leila Marat | Software Engineering |
| 502 | Temir Bek | Economics |
| 503 | Adina Kurman | Journalism |

- **Relation (table):** `students` is a collection of student records.
- **Tuple (row):** `(501, Leila Marat, Software Engineering)` is one record.
- **Attribute (column):** `student_id`, `student_name`, and `program` describe the records.
- **Domain / data type:** For example, `student_id` stores integer identifiers; names are text values.
- **Primary key (PK):** `student_id` identifies each student unambiguously.

The displayed row order is for readability; in the relational model, a table does not inherently guarantee an order of its rows.

## 4. Original Case Study — Campus Equipment Lending

### 4.1 The problem

A university equipment desk lends cameras, projectors, and audio devices to students. One student may borrow several items over time. The same item may be borrowed by different students on different dates. We need to track *students*, *equipment*, and *individual loans* without repeating a student's academic program and an item's description in every loan record.

### 4.2 Proposed relations

**Table A — `students`**

| student_id **(PK)** | student_name | program |
| ---: | --- | --- |
| 501 | Leila Marat | Software Engineering |
| 502 | Temir Bek | Economics |
| 503 | Adina Kurman | Journalism |

**Table B — `equipment`**

| equipment_id **(PK)** | item_name | category |
| ---: | --- | --- |
| 801 | Mirrorless Camera | Photography |
| 802 | Portable Projector | Presentation |
| 803 | Audio Recorder | Audio |

**Table C — `loans`**

| loan_id **(PK)** | student_id **(FK)** | equipment_id **(FK)** | borrowed_on | due_on |
| ---: | ---: | ---: | --- | --- |
| 901 | 501 | 801 | 2026-09-08 | 2026-09-11 |
| 902 | 503 | 803 | 2026-09-09 | 2026-09-12 |
| 903 | 501 | 802 | 2026-09-15 | 2026-09-18 |
| 904 | 502 | 801 | 2026-09-19 | 2026-09-22 |

All names, items and records are invented for this learning example; these tables do **not** claim to be exported from a live university system.

### 4.3 Entity relationships

![Relational model showing students, equipment and loans](output/relational-model.png)

**Figure 1.** Conceptual diagram of my Campus Equipment Lending example, designed for this lab (not a database execution screenshot).

The relationships are:

- `students` **1 → many** `loans`: one student may appear in several loan records; each loan references one student.
- `equipment` **1 → many** `loans`: one item may appear in several loan records over time; each loan references one item.
- `students` **many ↔ many** `equipment` *across time*: represented by the associative `loans` table.

The two foreign keys in `loans` connect the records. They do not by themselves prevent two students borrowing the same physical device at overlapping times; that additional business rule would need separate validation and is outside this introductory design.

### 4.4 Keys and referential integrity

| Key | Location | Function |
| --- | --- | --- |
| Primary key | `students.student_id` | Uniquely identifies a student. |
| Primary key | `equipment.equipment_id` | Uniquely identifies a piece of equipment. |
| Primary key | `loans.loan_id` | Uniquely identifies one borrowing event. |
| Foreign key | `loans.student_id` → `students.student_id` | Connects each loan to an existing student. |
| Foreign key | `loans.equipment_id` → `equipment.equipment_id` | Connects each loan to an existing item. |

A **primary key** must be unique and non-null. A **foreign key** imposes a reference to a valid record in the parent relation (subject to the table's nullability rules). Together, these constraints help maintain **referential integrity**.

For example, a new loan referencing equipment `999` should be rejected if no item with `equipment_id = 999` exists. This avoids a loan pointing to an unknown device.

## 5. Why Separate Tables?

A flat record might look like this:

| loan_id | student_name | program | item_name | category |
| ---: | --- | --- | --- | --- |
| 901 | Leila Marat | Software Engineering | Mirrorless Camera | Photography |
| 903 | Leila Marat | Software Engineering | Portable Projector | Presentation |

Here the student's name and program are copied on every borrowing record. This creates avoidable issues:

1. **Update anomaly:** if Leila changes her program, every matching loan row might need manual correction.
2. **Insertion anomaly:** information about a new item may be difficult to record when no student has borrowed it yet.
3. **Deletion anomaly:** deleting an old loan could accidentally remove the only stored description of an item.

By storing student and equipment details separately and keeping only their identifiers inside `loans`, the design reduces redundant data. This is the basic motivation behind relational design and **normalization**. Formal normal forms are studied in greater detail in later work.

## 6. Relational SQL vs. NoSQL Systems

| Feature | Relational / SQL approach | NoSQL approaches (varies by type) |
| --- | --- | --- |
| Data organization | Tables with rows and columns | Documents, key-value pairs, graph nodes/edges, etc. |
| Relationship modeling | Explicit keys and joins | Depends on product and data model; may embed or link records |
| Schema | Typically explicit, strongly constrained | Often flexible, but not necessarily schema-free |
| Querying | SQL is common | Different languages and APIs depending on product |
| Example technology | PostgreSQL | MongoDB (document-oriented) |
| Suitable example | Equipment inventory and linked loan records | Flexible collections of differently shaped device metadata |

Neither category is universally better. A relational approach fits this lending scenario because connections and consistency are central requirements. NoSQL databases can also provide strong consistency and transactions; the trade-offs depend on the specific technology and workload, not only the label "NoSQL."

## 7. ACID Properties — Introductory Explanation

A **transaction** is a group of database operations treated as one logical unit. ACID names four desirable properties:

| Property | Meaning | Equipment lending example |
| --- | --- | --- |
| **Atomicity** | Operations in a transaction succeed together or are rolled back together. | Creating a loan and changing an availability record should not succeed only halfway. |
| **Consistency** | Transactions preserve defined constraints and invariants. | A loan should not reference a nonexistent student. |
| **Isolation** | Concurrent transactions have controlled interactions. | Two desk staff borrowing equipment simultaneously should not corrupt records. |
| **Durability** | Committed changes survive according to the DBMS's guarantees. | A committed loan remains stored after a system restart. |

These are conceptual examples. This lab does **not** claim to have executed or tested transactional behavior.

## 8. Output and Results

The `output/` directory includes the **conceptual relational diagram** created for this report:

| File | What it demonstrates |
| --- | --- |
| [`output/relational-model.png`](output/relational-model.png) | Three entities, primary keys, foreign keys, and relationship cardinalities. |

Unlike later PostgreSQL labs, this introduction focuses on *understanding and designing* the relational model. There are **no simulated terminal screenshots or fabricated SQL outputs**. If the official Lab 1 handout explicitly requires practical screenshots, they must be captured from real work and added after checking that handout.

### Conceptual checks

| Question | Answer based on the proposed model |
| --- | --- |
| Can one student borrow multiple items over time? | Yes. Multiple `loans` may refer to the same `student_id`. |
| Can an item be lent again on a later date? | Yes. Multiple `loans` may refer to the same `equipment_id`. |
| Can a loan reference an unknown student? | Not when the foreign key constraint is enforced. |
| Is the equipment label repeated in each loan? | No. A loan stores the equipment identifier. |

## 9. Reflection and Conclusion

This lab helped me distinguish the **data model** from the **software** used to manage it. The Campus Equipment Lending scenario demonstrates how entities can be represented by tables and connected through keys. Splitting the design into students, equipment and loans avoids repeatedly storing descriptive information in each borrowing event. I also explored when relational databases are useful, how they differ from NoSQL approaches, and why ACID matters for reliable transactions.

The next lab focuses on installing and configuring PostgreSQL and pgAdmin, while subsequent labs introduce `psql` commands and SQL queries. For that reason, I have intentionally kept this first report **conceptual rather than turning it into a JOIN exercise**.

## 10. Learning References

- AUCA Databases course syllabus (Fall 2026), *Lab 1: Introduction to Relational Databases*.
- [PostgreSQL Documentation — Introduction](https://www.postgresql.org/docs/current/tutorial-intro.html).
- [PostgreSQL Documentation — Table Basics](https://www.postgresql.org/docs/current/tutorial-table.html).
- [PostgreSQL Documentation — Constraints](https://www.postgresql.org/docs/current/ddl-constraints.html).
