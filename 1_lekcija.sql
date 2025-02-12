-- Create the database if it doesn't exist
IF NOT EXISTS (
   SELECT name
   FROM sys.databases
   WHERE name = 'ElizaRiekstina1'
)
CREATE DATABASE ElizaRiekstina1 
ON (NAME='ElizaRiekstina1_Data',
    FILENAME='C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\ElizaRiekstina1.mdf',
    SIZE=100 MB,
    FILEGROWTH=5 MB)
LOG ON (NAME='ElizaRiekstina1_Log',
    FILENAME='C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\ElizaRiekstina1_Log.ldf',
    SIZE=5 MB,
    FILEGROWTH=1 MB)

USE ElizaRiekstina1
GO

-- Add a filegroup and file to the database
ALTER DATABASE ElizaRiekstina1 ADD FILEGROUP FG_NR2

ALTER DATABASE ElizaRiekstina1 ADD FILE (
    NAME='ElizaRiekstina1_Data2',
    FILENAME='C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\ElizaRiekstina1-2.ndf')
TO FILEGROUP FG_NR2

-- Create schemas and tables
CREATE SCHEMA Schema1;
CREATE SCHEMA Schema2;

CREATE TABLE Schema1.Table1 (
    id INT PRIMARY KEY,
    name NVARCHAR(100)
);

CREATE TABLE Schema2.Table2 (
    id INT PRIMARY KEY,
    description NVARCHAR(255)
);

-- Insert data into tables
INSERT INTO Schema1.Table1 (id, name) VALUES (1, 'Alice');
INSERT INTO Schema1.Table1 (id, name) VALUES (2, 'Bob');
INSERT INTO Schema1.Table1 (id, name) VALUES (3, 'Charlie');

INSERT INTO Schema2.Table2 (id, description) VALUES (1, 'Description 1');
INSERT INTO Schema2.Table2 (id, description) VALUES (2, 'Description 2');
INSERT INTO Schema2.Table2 (id, description) VALUES (3, 'Description 3');

-- Create a snapshot of the database
CREATE DATABASE ElizaRiekstina1_Snapshot ON
(NAME='ElizaRiekstina1', 
FILENAME='C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\ElizaRiekstina1_Snapshot.ss'),
(NAME='ElizaRiekstina1_Data2', 
FILENAME='C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\ElizaRiekstina1_Snapshot2.ss')
AS SNAPSHOT OF ElizaRiekstina1

-- Change data in one of the tables
UPDATE Schema1.Table1 SET name = 'Updated Alice' WHERE id = 1;

-- Select data from the snapshot tables
SELECT 'Snapshot' AS Source, * FROM ElizaRiekstina1_Snapshot.Schema1.Table1;
SELECT 'Snapshot' AS Source, * FROM ElizaRiekstina1_Snapshot.Schema2.Table2;

-- Select data from the source database tables
SELECT 'Source' AS Source, * FROM Schema1.Table1;
SELECT 'Source' AS Source, * FROM Schema2.Table2;

-- Compare data from Schema1.Table1
SELECT 
    'Snapshot' AS Source, id, name 
FROM 
    ElizaRiekstina1_Snapshot.Schema1.Table1
UNION ALL
SELECT 
    'Source' AS Source, id, name 
FROM 
    Schema1.Table1;

-- Compare data from Schema2.Table2
SELECT 
    'Snapshot' AS Source, id, description 
FROM 
    ElizaRiekstina1_Snapshot.Schema2.Table2
UNION ALL
SELECT 
    'Source' AS Source, id, description 
FROM 
    Schema2.Table2;

-- Drop the snapshot database and database
USE master
DROP DATABASE ElizaRiekstina1_Snapshot
DROP DATABASE ElizaRiekstina1