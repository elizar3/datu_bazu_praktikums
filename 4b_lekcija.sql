-- Izmanto datubāzi FragmentationDB
IF DB_ID('FragmentationDB') IS NOT NULL
    DROP DATABASE FragmentationDB;
GO

CREATE DATABASE FragmentationDB;
GO

USE FragmentationDB;
GO

---------------------------------------------------------------------------------------
-- 1. Izveido tabulu EmployeeActivity ar neklasterindeksu primāro atslēgu un 
--    klasterindeksu uz ActivityDate
---------------------------------------------------------------------------------------
CREATE TABLE EmployeeActivity (
    ActivityID INT IDENTITY(1,1) NOT NULL PRIMARY KEY NONCLUSTERED,  -- Primārā atslēga (neklasterindekss)
    EmployeeID INT NOT NULL,
    ActivityDate DATETIME2 NOT NULL,
    ActivityType NVARCHAR(50) NOT NULL
);
GO

-- Izveido klasterindeksu uz ActivityDate
CREATE CLUSTERED INDEX CIX_EmployeeActivity_ActivityDate
    ON EmployeeActivity (ActivityDate);
GO

---------------------------------------------------------------------------------------
-- 2. Aizpilda tabulu ar datiem (simulē 1000 ierakstus)
---------------------------------------------------------------------------------------
SET NOCOUNT ON;
DECLARE @i INT = 0;
WHILE @i < 1000
BEGIN
    INSERT INTO EmployeeActivity (EmployeeID, ActivityDate, ActivityType)
    VALUES (
        CAST(RAND() * 100 AS INT),
        DATEADD(SECOND, CAST(RAND() * 100000 AS INT), SYSDATETIME()),
        'Login'
    );
    SET @i = @i + 1;
END;
GO

---------------------------------------------------------------------------------------
-- 3. Parāda sākotnējo indeksu fragmentācijas rādītāju (DETAILED režīms)
---------------------------------------------------------------------------------------
SELECT *
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('EmployeeActivity'), NULL, NULL, 'DETAILED');
GO

---------------------------------------------------------------------------------------
-- 4. Modificē datus, lai palielinātu fragmentāciju (atjaunina ActivityDate)
---------------------------------------------------------------------------------------
UPDATE EmployeeActivity
SET ActivityDate = DATEADD(SECOND, CAST(RAND() * 1000 AS INT), ActivityDate);
GO

---------------------------------------------------------------------------------------
-- 5. Parāda indeksu fragmentācijas rādītāju pēc datu modifikācijas
---------------------------------------------------------------------------------------
SELECT *
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('EmployeeActivity'), NULL, NULL, 'DETAILED');
GO

---------------------------------------------------------------------------------------
-- 6. Veic klasterindeksa reorganizāciju, lai samazinātu fragmentāciju
---------------------------------------------------------------------------------------
ALTER INDEX CIX_EmployeeActivity_ActivityDate ON EmployeeActivity REORGANIZE;
GO

---------------------------------------------------------------------------------------
-- 7. Parāda indeksu fragmentācijas rādītāju pēc reorganizācijas
---------------------------------------------------------------------------------------
SELECT *
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('EmployeeActivity'), NULL, NULL, 'DETAILED');
GO

---------------------------------------------------------------------------------------
-- Tīrīšana: Dzēš tabulu pēc pārbaudes
---------------------------------------------------------------------------------------
DROP TABLE EmployeeActivity;
GO

---------------------------------------------------------------------------------------
-- Tīrīšana: Pārslēdzas atpakaļ uz master un izdzēš datubāzi
---------------------------------------------------------------------------------------
USE master;
GO

DROP DATABASE FragmentationDB;
GO


---------------------------------------------------------------------------------------
-- SimpleComplexQueries_DW2019.sql
-- Datubāze: AdventureWorksDW2019
-- Šajā failā ir divi vaicājumi:
-- 1. Vaicājums, kas apvieno datus no trim tabulām, izmantojot JOIN.
-- 2. Vaicājums, kas izmanto apakšvaicājumu un aritmētisku izteiksmi, lai aprēķinātu finanšu procentu.
---------------------------------------------------------------------------------------

USE AdventureWorksDW2019;
GO

---------------------------------------------------------------------------------------
-- Vaicājums 1: Datu atlase no trim tabulām ar JOIN
-- Šis vaicājums apvieno datus no:
--   - FactInternetSales (pārdošanas dati)
--   - DimCustomer (klientu dati)
--   - DimDate (datuma dati)
---------------------------------------------------------------------------------------
SELECT 
    dc.CustomerKey,
    dc.FirstName,
    dc.LastName,
    dd.FullDateAlternateKey AS OrderDate,
    fis.SalesAmount
FROM dbo.FactInternetSales AS fis
INNER JOIN dbo.DimCustomer AS dc
    ON fis.CustomerKey = dc.CustomerKey
INNER JOIN dbo.DimDate AS dd
    ON fis.OrderDateKey = dd.DateKey
WHERE dd.CalendarYear = 2020;
GO

---------------------------------------------------------------------------------------
-- Vaicājums 2: Finanšu procentu aprēķins ar apakšvaicājumu un aritmētisku izteiksmi
-- Šis vaicājums aprēķina katras organizācijas finanšu apjoma procentu no kopējā finanšu apjoma.
-- Tabulas:
--   - FactFinance (finanšu dati)
--   - DimOrganization (organizāciju dati)
---------------------------------------------------------------------------------------
SELECT 
    org.OrganizationName,
    SUM(ff.Amount) AS TotalFinance,
    (SUM(ff.Amount) * 100.0) / (SELECT SUM(Amount) FROM dbo.FactFinance) AS FinancePercent
FROM dbo.FactFinance AS ff
INNER JOIN dbo.DimOrganization AS org
    ON ff.OrganizationKey = org.OrganizationKey
GROUP BY org.OrganizationName;
GO
