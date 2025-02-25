---------------------------------------------------
-- Izveido jaunu datu bāzi un pārslēdzas uz to
---------------------------------------------------
IF DB_ID('ElizaDB') IS NOT NULL
    DROP DATABASE ElizaDB;
GO

CREATE DATABASE ElizaDB;
GO

USE ElizaDB;
GO

---------------------------------------------------
-- Izveido pielāgotu shēmu
---------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'TaskSchema')
    EXEC('CREATE SCHEMA TaskSchema');
GO

---------------------------------------------------
-- 1. Izveido MainTable ar dažādiem ierobežojumiem
---------------------------------------------------
CREATE TABLE TaskSchema.MainTable (
    ID INT NOT NULL,  -- Primārā atslēga (ievadīta manuāli)
    ColUnique NVARCHAR(50) NOT NULL,  -- Kolonna ar unikālu ierobežojumu
    ColCheck INT NOT NULL,            -- Kolonna ar check ierobežojumu (vērtībai jābūt > 0)
    ColDefault NVARCHAR(50) NOT NULL CONSTRAINT DF_MainTable_ColDefault DEFAULT ('DefaultValue'),
    NullableCol NVARCHAR(100) NULL,   -- Kolonna, kurai var būt NULL
    CONSTRAINT PK_MainTable PRIMARY KEY (ID),
    CONSTRAINT UQ_MainTable_ColUnique UNIQUE (ColUnique),
    CONSTRAINT CK_MainTable_ColCheck CHECK (ColCheck > 0)
);
GO

---------------------------------------------------
-- 2. Izveido ForeignTable, kas atsaucas uz MainTable (ON DELETE CASCADE)
---------------------------------------------------
CREATE TABLE TaskSchema.ForeignTable (
    ForeignID INT IDENTITY(1,1) NOT NULL,
    MainID INT NOT NULL,
    SomeData NVARCHAR(100) NULL,
    CONSTRAINT PK_ForeignTable PRIMARY KEY (ForeignID),
    CONSTRAINT FK_ForeignTable_MainID FOREIGN KEY (MainID)
         REFERENCES TaskSchema.MainTable(ID) ON DELETE CASCADE
);
GO

---------------------------------------------------
-- Datu manipulācijas operācijas MainTable
---------------------------------------------------

-- [Primārās atslēgas ierobežojuma demonstrācija]
PRINT '--- Primārās atslēgas ierobežojuma demonstrācija ---';
-- Veiksmīga ievietošana (ID=1)
INSERT INTO TaskSchema.MainTable (ID, ColUnique, ColCheck, NullableCol)
VALUES (1, 'Unique1', 10, 'Rinda1 dati');
GO

-- Neveiksmīga ievietošana: Dublēta primārā atslēga (ID=1)
BEGIN TRY
    INSERT INTO TaskSchema.MainTable (ID, ColUnique, ColCheck, NullableCol)
    VALUES (1, 'Unique2', 20, 'Dublēta PK rinda');
END TRY
BEGIN CATCH
    PRINT 'Kļūda (PK ierobežojuma pārkāpums): ' + ERROR_MESSAGE();
END CATCH;
GO

-- [Unikālā ierobežojuma demonstrācija]
PRINT '--- Unikālā ierobežojuma demonstrācija ---';
-- Veiksmīga ievietošana (ID=2, ColUnique='Unique2')
INSERT INTO TaskSchema.MainTable (ID, ColUnique, ColCheck, NullableCol)
VALUES (2, 'Unique2', 20, 'Rinda2 dati');
GO

-- Neveiksmīga atjaunināšana: ColUnique mainīšana uz vērtību, kas jau pastāv ('Unique1')
BEGIN TRY
    UPDATE TaskSchema.MainTable
    SET ColUnique = 'Unique1'
    WHERE ID = 2;
END TRY
BEGIN CATCH
    PRINT 'Kļūda (Unikālā ierobežojuma pārkāpums atjaunināšanā): ' + ERROR_MESSAGE();
END CATCH;
GO

-- [Check ierobežojuma demonstrācija]
PRINT '--- Check ierobežojuma demonstrācija ---';
-- Veiksmīga ievietošana (ID=3, ColCheck=30, kas ir > 0)
INSERT INTO TaskSchema.MainTable (ID, ColUnique, ColCheck, NullableCol)
VALUES (3, 'Unique3', 30, 'Rinda3 dati');
GO

-- Neveiksmīga ievietošana: Negatīva vērtība ColCheck (ID=4)
BEGIN TRY
    INSERT INTO TaskSchema.MainTable (ID, ColUnique, ColCheck, NullableCol)
    VALUES (4, 'Unique4', -5, 'Rinda4 dati');
END TRY
BEGIN CATCH
    PRINT 'Kļūda (Check ierobežojuma pārkāpums ievietā): ' + ERROR_MESSAGE();
END CATCH;
GO

-- Neveiksmīga atjaunināšana: Maina ColCheck uz 0 (pārkāpj > 0) rindai ar ID=3
BEGIN TRY
    UPDATE TaskSchema.MainTable
    SET ColCheck = 0
    WHERE ID = 3;
END TRY
BEGIN CATCH
    PRINT 'Kļūda (Check ierobežojuma pārkāpums atjaunināšanā): ' + ERROR_MESSAGE();
END CATCH;
GO

-- [Default ierobežojuma demonstrācija]
PRINT '--- Default ierobežojuma demonstrācija ---';
-- Veiksmīga ievietošana, izmantojot noklusējuma vērtību (ID=5, kolonna ColDefault tiek izlaista)
INSERT INTO TaskSchema.MainTable (ID, ColUnique, ColCheck, NullableCol)
VALUES (5, 'Unique5', 50, 'Rinda5 dati');
GO

---------------------------------------------------
-- Datu manipulācijas operācijas ForeignTable
---------------------------------------------------

PRINT '--- Ārējās atslēgas ierobežojuma demonstrācija ---';
-- Veiksmīga ievietošana: Atsaucas uz esošiem MainTable ierakstiem (ID=2 un ID=5)
INSERT INTO TaskSchema.ForeignTable (MainID, SomeData)
VALUES (2, 'Ārējā rinda 1'), (5, 'Ārējā rinda 2');
GO

-- Neveiksmīga ievietošana: Atsauce uz neesošu MainTable ierakstu (ID=999)
BEGIN TRY
    INSERT INTO TaskSchema.ForeignTable (MainID, SomeData)
    VALUES (999, 'Nederīga ārējā rinda');
END TRY
BEGIN CATCH
    PRINT 'Kļūda (Ārējās atslēgas ierobežojuma pārkāpums ievietošanā): ' + ERROR_MESSAGE();
END CATCH;
GO

-- Neveiksmīga atjaunināšana: Maina MainID uz nederīgu vērtību (999)
BEGIN TRY
    UPDATE TaskSchema.ForeignTable
    SET MainID = 999
    WHERE ForeignID = (SELECT TOP 1 ForeignID FROM TaskSchema.ForeignTable);
END TRY
BEGIN CATCH
    PRINT 'Kļūda (Ārējās atslēgas ierobežojuma pārkāpums atjaunināšanā): ' + ERROR_MESSAGE();
END CATCH;
GO

-- [ON DELETE CASCADE demonstrācija]
PRINT '--- ON DELETE CASCADE demonstrācija ---';
-- Pirms dzēšanas: parāda ForeignTable rindas
PRINT 'Ārējās tabulas rindas pirms dzēšanas:';
SELECT * FROM TaskSchema.ForeignTable;
GO

-- Veiksmīga dzēšana: Dzēš MainTable ierakstu ar ID=2,
-- kas izraisīs saistīto ForeignTable ierakstu dzēšanu (cascade)
DELETE FROM TaskSchema.MainTable
WHERE ID = 2;
GO

PRINT 'Ārējās tabulas rindas pēc cascading dzēšanas:';
SELECT * FROM TaskSchema.ForeignTable;
GO

---------------------------------------------------
-- Tīrīšana: Pārslēdzas atpakaļ uz master un izdzēš datu bāzi
---------------------------------------------------
USE master;
GO

DROP DATABASE ElizaDB;
GO
