-- Izveido datu bāzi, ja tā neeksistē
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

-- Izveido shēmu
CREATE SCHEMA TaskSchema
GO

-- Izveido pielāgotus datu tipus shēmā TaskSchema
CREATE TYPE TaskSchema.IntType FROM INT NOT NULL;
CREATE TYPE TaskSchema.StringType FROM NVARCHAR(255) NULL;
CREATE TYPE TaskSchema.DateType FROM DATE NOT NULL;
GO

-- Pievieno failu grupas un failus particionēšanai
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

ALTER DATABASE ElizaRiekstina2 ADD FILE 
( NAME = data4, FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\ElizaRiekstina2_4.ndf', SIZE = 10 MB, FILEGROWTH = 5 MB) TO FILEGROUP fg4;
GO

-- Izveido particionēšanas funkciju
CREATE PARTITION FUNCTION pf_DatePartition (DATE)
AS RANGE RIGHT FOR VALUES ('2023-01-01', '2024-01-01')
GO

-- Izveido particionēšanas shēmu
CREATE PARTITION SCHEME ps_DatePartition
AS PARTITION pf_DatePartition
TO (fg1, fg2, fg3, fg4)
GO

-- Maina particionēšanas shēmu, lai nākamā izmantotā failu grupa būtu fg4
ALTER PARTITION SCHEME ps_DatePartition NEXT USED fg4
GO

-- Izveido particionētu tabulu shēmā TaskSchema ar klasterizētu indeksu uz EntryDate,
-- izmantojot shēmā TaskSchema izveidotos datu tipus
CREATE TABLE TaskSchema.PartitionedTable (
    ID INT IDENTITY(1,1) NOT NULL,
    Name TaskSchema.StringType,
    EntryDate TaskSchema.DateType,
    PrecisionData DECIMAL(10,2),
    ApproxData FLOAT,
    CustomInt TaskSchema.IntType,
    CustomString TaskSchema.StringType,
    CustomDate TaskSchema.DateType,
    ComputedColumn AS (PrecisionData * 2),
    CONSTRAINT PK_PartitionedTable PRIMARY KEY CLUSTERED (ID, EntryDate)
) ON ps_DatePartition(EntryDate)
GO

-- Ievieto parauga datus, lai katrā particijā būtu vismaz 2 ieraksti
INSERT INTO TaskSchema.PartitionedTable (Name, EntryDate, PrecisionData, ApproxData, CustomInt, CustomString, CustomDate)
VALUES ('Record1', '2022-11-15', 9.50, 9.5, 1, 'Test1', '2022-11-15'),
       ('Record2', '2022-12-31', 8.75, 8.8, 2, 'Test2', '2022-12-31'),
       ('Record3', '2023-05-20', 10.50, 10.5, 3, 'Test3', '2023-05-20'),
       ('Record4', '2023-11-15', 12.00, 12.1, 4, 'Test4', '2023-11-15'),
       ('Record5', '2024-06-15', 20.75, 20.7, 5, 'Test5', '2024-05-15'),
       ('Record6', '2024-09-01', 22.30, 22.3, 6, 'Test6', '2024-09-01');
GO

-- Parāda partīciju metadatus
SELECT ps.name AS PartitionScheme, pf.name AS PartitionFunction, p.partition_number, COUNT(*) AS RecordCount
FROM sys.partitions p
JOIN sys.indexes i ON p.object_id = i.object_id AND p.index_id = i.index_id
JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
JOIN sys.partition_functions pf ON ps.function_id = pf.function_id
WHERE i.object_id = OBJECT_ID('TaskSchema.PartitionedTable')
GROUP BY ps.name, pf.name, p.partition_number
ORDER BY p.partition_number
GO

-- Parāda rindu skaitu katrā particijā
SELECT partition_number, rows AS RecordCount
FROM sys.partitions
WHERE object_id = OBJECT_ID('TaskSchema.PartitionedTable')
  AND index_id = 1  -- klasterizētais indekss
ORDER BY partition_number;
GO

-- Izveido arhīva tabulu shēmā TaskSchema ar atbilstošu struktūru un particionēšanu,
-- izmantojot shēmā TaskSchema izveidotos datu tipus
CREATE TABLE TaskSchema.ArchiveTable (
    ID INT IDENTITY(1,1) NOT NULL,
    Name TaskSchema.StringType,
    EntryDate TaskSchema.DateType,
    PrecisionData DECIMAL(10,2),
    ApproxData FLOAT,
    CustomInt TaskSchema.IntType,
    CustomString TaskSchema.StringType,
    CustomDate TaskSchema.DateType,
    ComputedColumn AS (PrecisionData * 2),
    CONSTRAINT PK_ArchiveTable PRIMARY KEY CLUSTERED (ID, EntryDate)
) ON ps_DatePartition(EntryDate)
GO

-- Pārnes partīciju uz arhīva tabulu
ALTER TABLE TaskSchema.PartitionedTable
SWITCH PARTITION 1 TO TaskSchema.ArchiveTable PARTITION 1;
GO

-- Parāda partīciju metadatus pēc pārcelšanas
SELECT * FROM sys.partitions WHERE [object_id] = OBJECT_ID('TaskSchema.PartitionedTable')
GO

-- Apvieno divas partīcijas
ALTER PARTITION FUNCTION pf_DatePartition() MERGE RANGE ('2023-01-01')
GO

-- Parāda partīciju metadatus pēc apvienošanas
SELECT * FROM sys.partitions WHERE [object_id] = OBJECT_ID('TaskSchema.PartitionedTable')
GO

-- Sadala partīciju pēc tam, kad tika norādīta nākamā izmantotā failu grupa
ALTER PARTITION FUNCTION pf_DatePartition() SPLIT RANGE ('2024-06-01')
GO

-- Parāda partīciju metadatus pēc sadalīšanas
SELECT * FROM sys.partitions WHERE [object_id] = OBJECT_ID('TaskSchema.PartitionedTable')
GO

-- Izdzēš tabulas un particionēšanas shēmu/funkciju
DROP TABLE TaskSchema.PartitionedTable
DROP TABLE TaskSchema.ArchiveTable
DROP PARTITION SCHEME ps_DatePartition
DROP PARTITION FUNCTION pf_DatePartition
GO

USE master
DROP DATABASE ElizaRiekstina2
GO

-- Izveido pagaidu tabulu, ievieto datus un pārbauda rezultātus
USE tempdb
CREATE TABLE #TempTable (
    ID INT PRIMARY KEY,
    Name NVARCHAR(100)
)
GO

INSERT INTO #TempTable (ID, Name) VALUES (1, 'TempRecord1'), (2, 'TempRecord2')
GO

-- Atvieno savienojumu, aizver vaicājumu un parāda pagaidu tabulas datus
SELECT * FROM #TempTable
GO