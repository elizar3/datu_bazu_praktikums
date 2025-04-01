/* 1. Izveido skatu no 3 tabulām (Klienti, Pasūtījumi, Produkti) savienojot pēc atslēgu kolonnām */

/* Izveido datubāzi un tabulas ar piemēra datiem */
IF DB_ID('TestDB') IS NOT NULL
    DROP DATABASE TestDB;
GO
CREATE DATABASE TestDB;
GO
USE TestDB;
GO

/* Izveido tabulu Klienti */
CREATE TABLE dbo.Klienti (
    KlientaID INT PRIMARY KEY,
    KlientaVards NVARCHAR(50)
);
GO

/* Izveido tabulu Produkti */
CREATE TABLE dbo.Produkti (
    ProduktaID INT PRIMARY KEY,
    ProduktaNosaukums NVARCHAR(50),
    Cena DECIMAL(10,2)
);
GO

/* Izveido tabulu Pasūtījumi ar ārējām atslēgām */
CREATE TABLE dbo.Pasutijumi (
    PasutijumaID INT PRIMARY KEY,
    KlientaID INT,
    ProduktaID INT,
    PasutijumaDatums DATE,
    CONSTRAINT FK_Klienti FOREIGN KEY (KlientaID) REFERENCES dbo.Klienti(KlientaID),
    CONSTRAINT FK_Produkti FOREIGN KEY (ProduktaID) REFERENCES dbo.Produkti(ProduktaID)
);
GO

/* Ievieto piemēra datus tabulā Klienti */
INSERT INTO dbo.Klienti VALUES 
    (1, 'Anna'),
    (2, 'Jānis'),
    (3, 'Ilze'),
    (4, 'Pēteris'),
    (5, 'Marija'),
    (6, 'Edgars');
GO

/* Ievietopiemēra datus tabulā Produkti */
INSERT INTO dbo.Produkti VALUES 
    (100, 'Datortehnika', 1500.00),
    (101, 'Planšete', 900.00),
    (102, 'Viedtālrunis', 600.00),
    (103, 'Drukātājs', 300.00),
    (104, 'Monitoru komplekts', 800.00);
GO

/* Ievieto piemēra datus tabulā Pasūtījumi */
INSERT INTO dbo.Pasutijumi VALUES 
    (1000, 1, 100, '2022-06-01'),
    (1001, 2, 101, '2022-07-15'),
    (1002, 3, 102, '2022-08-20'),
    (1003, 1, 101, '2022-09-10'),
    (1004, 4, 103, '2022-03-25'),
    (1005, 5, 104, '2022-04-30'),
    (1006, 6, 102, '2022-11-05'),
    (1007, 2, 104, '2022-12-12'),
    (1008, 3, 103, '2022-10-18'),
    (1009, 5, 100, '2022-02-14');
GO

/* Izveido skatu, kas savieno Klientus, Pasūtījumus un Produktus */
CREATE VIEW dbo.View_PasutijumiDetalas
WITH SCHEMABINDING
AS
SELECT 
    k.KlientaID,
    k.KlientaVards,
    p.PasutijumaID,
    p.PasutijumaDatums,
    pr.ProduktaID,
    pr.ProduktaNosaukums,
    pr.Cena
FROM dbo.Klienti k
JOIN dbo.Pasutijumi p ON k.KlientaID = p.KlientaID
JOIN dbo.Produkti pr ON p.ProduktaID = pr.ProduktaID;
GO

/* 2. Izveido SQL SELECT vaicājumu, kas atlasa vairākas rindas no skata */
SELECT * FROM dbo.View_PasutijumiDetalas;
GO

/* 3. Pārveido skatu par indeksētu, pievienojot unikālu klasterizēto indeksu */
CREATE UNIQUE CLUSTERED INDEX IX_View_PasutijumiDetalas
ON dbo.View_PasutijumiDetalas(KlientaID, PasutijumaID);
GO

/* 4. Izveido modificējamu skatu no 2 tabulām (Pasūtījumi un Klienti) ar WHERE nosacījumu un WITH CHECK OPTION */
CREATE VIEW dbo.View_PasutijumiModifcejams
AS
SELECT 
    p.PasutijumaID,
    p.KlientaID,
    p.PasutijumaDatums
FROM dbo.Pasutijumi p
JOIN dbo.Klienti k ON p.KlientaID = k.KlientaID
WHERE p.PasutijumaDatums >= '2022-01-01'
WITH CHECK OPTION;
GO

/* 5. Atlasa datus no modificējāmā skata, veic UPDATE komandu un pārbauda izmaiņas */
SELECT * FROM dbo.View_PasutijumiModifcejams;
GO

-- Veic izmaiņas, atjauninot pasūtījuma datumu uz derīgu vērtību
UPDATE dbo.View_PasutijumiModifcejams
SET PasutijumaDatums = '2024-05-05'
WHERE PasutijumaID = 1000;
GO

SELECT * FROM dbo.View_PasutijumiModifcejams;
GO

/* 6. Veic UPDATE komandu, kas neizdodas ar WITH CHECK OPTION (datums pirms 2022-01-01) */
BEGIN TRY
    UPDATE dbo.View_PasutijumiModifcejams
    SET PasutijumaDatums = '2021-06-20'
    WHERE PasutijumaID = 1001;
END TRY
BEGIN CATCH
    PRINT 'Kļūda: ' + ERROR_MESSAGE();
END CATCH;
GO

USE master;
GO

DROP DATABASE TestDB;
GO