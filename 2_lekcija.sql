-- Create the database if it doesn't exist
IF NOT EXISTS (
   SELECT name
   FROM sys.databases
   WHERE name = 'ElizaRiekstina2'
)
CREATE DATABASE ElizaRiekstina2 
ON (NAME='ElizaRiekstina2_Data',
    FILENAME='C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\ElizaRiekstina2.mdf',
    SIZE=100 MB,
    FILEGROWTH=5 MB)
LOG ON (NAME='ElizaRiekstina2_Log',
    FILENAME='C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\ElizaRiekstina2_Log.ldf',
    SIZE=5 MB,
    FILEGROWTH=1 MB)
GO

USE ElizaRiekstina2
GO

-- Create schema
CREATE SCHEMA TaskSchema
GO

-- Create custom data types
CREATE TYPE IntType FROM INT NOT NULL
CREATE TYPE StringType FROM NVARCHAR(255) NULL
CREATE TYPE DateType FROM DATE NOT NULL
GO

-- Add filegroups and files for partitioning
ALTER DATABASE ElizaRiekstina2 ADD FILEGROUP fg1
ALTER DATABASE ElizaRiekstina2 ADD FILEGROUP fg2
ALTER DATABASE ElizaRiekstina2 ADD FILEGROUP fg3
ALTER DATABASE ElizaRiekstina2 ADD FILEGROUP fg4
GO

ALTER DATABASE ElizaRiekstina2 ADD FILE 
( NAME = data1, FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\ElizaRiekstina2_1.ndf') TO FILEGROUP fg1
ALTER DATABASE ElizaRiekstina2 ADD FILE 
( NAME = data2, FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\ElizaRiekstina2_2.ndf') TO FILEGROUP fg2
ALTER DATABASE ElizaRiekstina2 ADD FILE 
( NAME = data3, FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\ElizaRiekstina2_3.ndf') TO FILEGROUP fg3
GO

-- Create partition function
CREATE PARTITION FUNCTION pf_DatePartition (DATE)
AS RANGE RIGHT FOR VALUES ('2023-01-01', '2024-01-01')
GO

-- Create partition scheme
CREATE PARTITION SCHEME ps_DatePartition
AS PARTITION pf_DatePartition
TO (fg1, fg2, fg3, fg4)
GO

-- Alter partition scheme to set the next used filegroup
ALTER PARTITION SCHEME ps_DatePartition NEXT USED fg4
GO

-- Create partitioned table with clustered index on EntryDate
CREATE TABLE TaskSchema.PartitionedTable (
    ID INT IDENTITY(1,1) NOT NULL,
    Name StringType,
    EntryDate DateType,
    PrecisionData DECIMAL(10,2),
    ApproxData FLOAT,
    CustomInt IntType,
    CustomString StringType,
    CustomDate DateType,
    ComputedColumn AS (PrecisionData * 2),
    CONSTRAINT PK_PartitionedTable PRIMARY KEY CLUSTERED (ID, EntryDate)
) ON ps_DatePartition(EntryDate)
GO

-- Insert sample data ensuring each partition has at least 2 records
INSERT INTO TaskSchema.PartitionedTable (Name, EntryDate, PrecisionData, ApproxData, CustomInt, CustomString, CustomDate)
VALUES ('Record1', '2023-12-31', 10.50, 10.5, 1, 'Test1', '2023-12-31'),
       ('Record2', '2023-11-15', 12.00, 12.1, 2, 'Test2', '2023-11-15'),
       ('Record3', '2024-06-15', 20.75, 20.7, 3, 'Test3', '2024-06-15'),
       ('Record4', '2024-09-01', 22.30, 22.3, 4, 'Test4', '2024-09-01')
GO

-- Display partition metadata
SELECT ps.name AS PartitionScheme, pf.name AS PartitionFunction, p.partition_number, COUNT(*) AS RecordCount
FROM sys.partitions p
JOIN sys.indexes i ON p.object_id = i.object_id AND p.index_id = i.index_id
JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
JOIN sys.partition_functions pf ON ps.function_id = pf.function_id
WHERE i.object_id = OBJECT_ID('TaskSchema.PartitionedTable')
GROUP BY ps.name, pf.name, p.partition_number
ORDER BY p.partition_number
GO

-- Create archive table with matching structure
CREATE TABLE TaskSchema.ArchiveTable (
    ID INT IDENTITY(1,1) NOT NULL,
    Name StringType,
    EntryDate DateType,
    PrecisionData DECIMAL(10,2),
    ApproxData FLOAT,
    CustomInt IntType,
    CustomString StringType,
    CustomDate DateType,
    ComputedColumn AS (PrecisionData * 2),
    CONSTRAINT PK_ArchiveTable PRIMARY KEY CLUSTERED (ID, EntryDate)
) ON fg1
GO

-- Switch a partition to archive table
ALTER TABLE TaskSchema.PartitionedTable SWITCH PARTITION 1 TO TaskSchema.ArchiveTable
GO

-- Display partition metadata after switching
SELECT * FROM sys.partitions WHERE [object_id] = OBJECT_ID('TaskSchema.PartitionedTable')
GO

-- Merge two partitions
ALTER PARTITION FUNCTION pf_DatePartition() MERGE RANGE ('2023-01-01')
GO

-- Display partition metadata after merging
SELECT * FROM sys.partitions WHERE [object_id] = OBJECT_ID('TaskSchema.PartitionedTable')
GO

-- Split partition after adding NEXT USED filegroup
ALTER PARTITION FUNCTION pf_DatePartition() SPLIT RANGE ('2024-06-01')
GO

-- Display partition metadata after splitting
SELECT * FROM sys.partitions WHERE [object_id] = OBJECT_ID('TaskSchema.PartitionedTable')
GO

-- Drop the table and database
DROP TABLE TaskSchema.PartitionedTable
DROP TABLE TaskSchema.ArchiveTable
DROP PARTITION SCHEME ps_DatePartition
DROP PARTITION FUNCTION pf_DatePartition
GO

USE master
DROP DATABASE ElizaRiekstina2
GO

-- Create temporary table, insert and verify data
USE tempdb
CREATE TABLE #TempTable (
    ID INT PRIMARY KEY,
    Name NVARCHAR(100)
)
GO

INSERT INTO #TempTable (ID, Name) VALUES (1, 'TempRecord1'), (2, 'TempRecord2')
GO

SELECT * FROM #TempTable
GO
