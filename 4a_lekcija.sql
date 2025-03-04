-- Izmanto datubāzi ElizaDB
IF DB_ID('ElizaDB') IS NOT NULL
    DROP DATABASE ElizaDB;
GO

CREATE DATABASE ElizaDB;
GO

USE ElizaDB;
GO

---------------------------------------------------------------------------------------
-- 1. Izveido tabulu Customer ar klasterindeksu (primāro atslēgu)
---------------------------------------------------------------------------------------
CREATE TABLE Customer (
    CustomerID INT IDENTITY(1,1) PRIMARY KEY,  -- Klasterindekss
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    Email NVARCHAR(100) NOT NULL,
    RegistrationDate DATE NULL,
    Age INT NOT NULL,
    CreditLimit DECIMAL(10,2) NOT NULL,
    PurchaseCount INT NOT NULL
);
GO

---------------------------------------------------------------------------------------
-- Izveido unikālu neklasterindeksu uz Email kolonnas
---------------------------------------------------------------------------------------
CREATE UNIQUE NONCLUSTERED INDEX IDX_Customer_Email
    ON Customer (Email);
GO

---------------------------------------------------------------------------------------
-- Izveido kompozītu (saliktu) neklasterindeksu uz CreditLimit un PurchaseCount
---------------------------------------------------------------------------------------
CREATE NONCLUSTERED INDEX IDX_Customer_CreditPurchase
    ON Customer (CreditLimit, PurchaseCount);
GO

---------------------------------------------------------------------------------------
-- Izveido filtrētu neklasterindeksu uz Age kolonnas, 
-- kad RegistrationDate nav NULL
---------------------------------------------------------------------------------------
CREATE NONCLUSTERED INDEX IDX_Customer_AgeFiltered
    ON Customer (Age)
    WHERE RegistrationDate IS NOT NULL;
GO

---------------------------------------------------------------------------------------
-- 2. Izveido tabulu Sales ar klasterindeksu un izrēķinātu kolonnu
---------------------------------------------------------------------------------------
CREATE TABLE Sales (
    SalesID INT IDENTITY(1,1) PRIMARY KEY,  -- Klasterindekss
    OrderNumber NVARCHAR(50) NOT NULL,
    Quantity INT NOT NULL,
    PricePerUnit DECIMAL(10,2) NOT NULL,
    TotalPrice AS (Quantity * PricePerUnit) PERSISTED  -- Izrēķināta kolonna
);
GO

---------------------------------------------------------------------------------------
-- Izveido unikālu neklasterindeksu uz OrderNumber kolonnas
---------------------------------------------------------------------------------------
CREATE UNIQUE NONCLUSTERED INDEX IDX_Sales_OrderNumber
    ON Sales (OrderNumber);
GO

---------------------------------------------------------------------------------------
-- Izveido neklasterindeksu uz izrēķināto kolonnu TotalPrice
---------------------------------------------------------------------------------------
CREATE NONCLUSTERED INDEX IDX_Sales_TotalPrice
    ON Sales (TotalPrice);
GO

---------------------------------------------------------------------------------------
-- 3. Izveido tabulu Location ar klasterindeksu
---------------------------------------------------------------------------------------
CREATE TABLE Location (
    LocationID INT IDENTITY(1,1) PRIMARY KEY,  -- Klasterindekss
    Country NVARCHAR(50) NOT NULL,
    City NVARCHAR(50) NOT NULL,
    Address NVARCHAR(100) NOT NULL,
    ZipCode NVARCHAR(10) NOT NULL
);
GO

---------------------------------------------------------------------------------------
-- Izveido neklasterindeksu uz ZipCode kolonnas, iekļaujot papildus 
-- kolonnas Country, City un Address
---------------------------------------------------------------------------------------
CREATE NONCLUSTERED INDEX IDX_Location_ZipCode
    ON Location (ZipCode)
    INCLUDE (Country, City, Address);
GO

---------------------------------------------------------------------------------------
-- Aizpilda tabulu Customer ar datiem
---------------------------------------------------------------------------------------
INSERT INTO Customer (FirstName, LastName, Email, RegistrationDate, Age, CreditLimit, PurchaseCount)
VALUES
('Andris', 'Kalniņš', 'andris.k@example.com', '2015-04-12', 34, 1500.00, 10),
('Marija', 'Liepa', 'marija.l@example.com', '2018-07-23', 28, 2300.50, 15),
('Guntis', 'Ozoliņš', 'guntis.o@example.com', NULL, 45, 3200.75, 8),
('Elza', 'Bērziņa', 'elza.b@example.com', '2020-01-10', 31, 1800.00, 12),
('Rihards', 'Ziediņš', 'rihards.z@example.com', '2012-11-05', 50, 5000.00, 20);
GO

---------------------------------------------------------------------------------------
-- Aizpilda tabulu Sales ar datiem
---------------------------------------------------------------------------------------
INSERT INTO Sales (OrderNumber, Quantity, PricePerUnit)
VALUES
('ORD1001', 5, 99.99),
('ORD1002', 10, 49.50),
('ORD1003', 3, 199.95),
('ORD1004', 7, 29.99),
('ORD1005', 2, 499.99);
GO

---------------------------------------------------------------------------------------
-- Aizpilda tabulu Location ar datiem
---------------------------------------------------------------------------------------
INSERT INTO Location (Country, City, Address, ZipCode)
VALUES
('USA', 'New York', '123 Broadway Ave', '10007'),
('Latvia', 'Riga', '45 Brivibas Street', 'LV-1010'),
('Germany', 'Berlin', '78 Alexanderplatz', '10115'),
('France', 'Paris', '10 Champs Elysees', '75008'),
('UK', 'London', '221B Baker Street', 'NW1 6XE');
GO

---------------------------------------------------------------------------------------
-- Vaicājumi ar WHERE nosacījumiem, lai pārbaudītu katra izveidotā indeksa izmantošanu
-- (skatīt Execution Plan ar CTRL+M)
---------------------------------------------------------------------------------------

-- 1. Vaicājums izmanto filtrēto indeksu IDX_Customer_AgeFiltered
SELECT FirstName, LastName, Age
FROM Customer
WHERE RegistrationDate IS NOT NULL
ORDER BY Age ASC;
GO

-- 2. Vaicājums izmanto kompozītu indeksu IDX_Customer_CreditPurchase
SELECT FirstName, LastName, CreditLimit, PurchaseCount
FROM Customer
WHERE CreditLimit >= 1500 AND PurchaseCount >= 10
ORDER BY CreditLimit DESC;
GO

-- 3. Vaicājums izmanto indeksētu izrēķināto kolonnu TotalPrice (indekss IDX_Sales_TotalPrice)
SELECT OrderNumber, TotalPrice
FROM Sales
WHERE TotalPrice > 300
ORDER BY TotalPrice DESC;
GO

-- 4. Vaicājums izmanto unikālo indeksu IDX_Sales_OrderNumber
SELECT SalesID, OrderNumber
FROM Sales
WHERE OrderNumber = 'ORD1003';
GO

-- 5. Vaicājums izmanto indeksu ar iekļautajām kolonnām IDX_Location_ZipCode
SELECT Country, City, Address
FROM Location
WHERE ZipCode = 'LV-1010';
GO

---------------------------------------------------------------------------------------
-- Execution Plan (CTRL+M), lai redzētu izmantotos indeksus.
---------------------------------------------------------------------------------------

-- Dzēšam tabulas pēc pārbaudes
DROP TABLE Customer;
DROP TABLE Sales;
DROP TABLE Location;
GO

---------------------------------------------------------------------------------------
-- Tīrīšana: Pārslēdzas atpakaļ uz master un izdzēš datu bāzi
---------------------------------------------------------------------------------------
USE master;
GO

DROP DATABASE ElizaDB;
GO