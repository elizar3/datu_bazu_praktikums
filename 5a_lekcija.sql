CREATE DATABASE ElizaDB;
GO

USE ElizaDB;
GO

------------------------------------------------------------
-- 1. Izveido tabulu ar vienu XML tipa kolonnu un vienu citu datu tipu kolonnu.
------------------------------------------------------------
IF OBJECT_ID('dbo.XmlTest', 'U') IS NOT NULL
    DROP TABLE dbo.XmlTest;
GO

CREATE TABLE dbo.XmlTest
(
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Apraksts NVARCHAR(100),
    XmlDati XML
);
GO

------------------------------------------------------------
-- 2. Izveido primāro XML indeksu un 3 sekundāros XML indeksus (PATH, VALUE, PROPERTY)
--    kolonnā XmlDati.
------------------------------------------------------------
-- Primārais XML indekss
CREATE PRIMARY XML INDEX PXML_XmlTest_XmlDati ON dbo.XmlTest(XmlDati);
GO

-- Sekundārais XML indekss ar PATH
CREATE XML INDEX SI_XmlTest_Path ON dbo.XmlTest(XmlDati)
    USING XML INDEX PXML_XmlTest_XmlDati FOR PATH;
GO

-- Sekundārais XML indekss ar VALUE
CREATE XML INDEX SI_XmlTest_Value ON dbo.XmlTest(XmlDati)
    USING XML INDEX PXML_XmlTest_XmlDati FOR VALUE;
GO

-- Sekundārais XML indekss ar PROPERTY
CREATE XML INDEX SI_XmlTest_Property ON dbo.XmlTest(XmlDati)
    USING XML INDEX PXML_XmlTest_XmlDati FOR PROPERTY;
GO

------------------------------------------------------------
-- 3. Aizpilda tabulu ar datiem.
--    Pirmajā ierakstā XML dati satur vairākus <Prece> elementus, lai ar nodes metodi
--    varētu atdalīt vairākas rindas no vienas XML vērtības.
------------------------------------------------------------
INSERT INTO dbo.XmlTest (Apraksts, XmlDati)
VALUES 
('Pasūtījums ar precēm', 
'<Pasutijums>
    <Prece ID="201" Nosaukums="Bumbieri" Cena="1.25" />
    <Prece ID="202" Nosaukums="Āboli" Cena="0.75" />
    <Prece ID="203" Nosaukums="Bumbas" Cena="2.10" />
</Pasutijums>'),
('Klienta dati',
'<Klients>
    <Vards>Anna Kalniņa</Vards>
    <Kontakti Epasts="anna.k@example.com" Telefons="987-654-3210" />
</Klients>');
GO

------------------------------------------------------------
-- 4. Atlasīt datus no XML tipa kolonnas, izmantojot query, value un exist metodes.
------------------------------------------------------------

-- Izmantojot query() metodi, lai iegūtu visus <Prece> elementus.
SELECT ID, Apraksts,
       XmlDati.query('/Pasutijums/Prece') AS Preces
FROM dbo.XmlTest
WHERE Apraksts = 'Pasūtījums ar precēm';
GO

-- Izmantojot value() metodi, lai iegūtu pirmā <Prece> elementa Nosaukums atribūtu.
SELECT ID, Apraksts,
       XmlDati.value('(/Pasutijums/Prece/@Nosaukums)[1]', 'nvarchar(50)') AS PirmasPrecesNosaukums
FROM dbo.XmlTest
WHERE Apraksts = 'Pasūtījums ar precēm';
GO

-- Izmantojot exist() metodi, lai pārbaudītu, vai vismaz vienai <Prece> ir Cena < 1.00.
SELECT ID, Apraksts,
       XmlDati.exist('/Pasutijums/Prece[@Cena < 1.00]') AS IrTadaPrece
FROM dbo.XmlTest
WHERE Apraksts = 'Pasūtījums ar precēm';
GO

-- Izmantojot sql:column funkciju, lai iekļautu ne-XML kolonnu vaicājumā.
-- Šis vaicājums izveido jaunu XML mezglu, kas satur arī Apraksts vērtību.
SELECT ID, Apraksts,
       XmlDati.query('
         for $p in /Pasutijums/Prece 
         return 
            <Rezultats>
               {$p/@Nosaukums} 
               <Apraks>{sql:column("Aprakststs")}</Apraks>
            </Rezultats>
       ') AS PrecesArAprakstu
FROM dbo.XmlTest
WHERE Apraksts = 'Pasūtījums ar precēm';
GO

------------------------------------------------------------
-- 5. Rediģē datus XML tipa kolonnā, izmantojot modify() metodi.
--    Veic sekojošas darbības: pievieno jaunu mezglu, nomaina vērtību un izmet mezglu.
------------------------------------------------------------

-- Parāda sākotnējos XML datus.
PRINT 'Sākotnējie XML dati:';
SELECT ID, XmlDati 
FROM dbo.XmlTest
WHERE Apraksts = 'Pasūtījums ar precēm';
GO

-- (a) Pievieno jaunu <Prece> elementu.
UPDATE dbo.XmlTest
SET XmlDati.modify('insert <Prece ID="204" Nosaukums="Kivi" Cena="1.90" /> as last into (/Pasutijums)[1]')
WHERE Apraksts = 'Pasūtījums ar precēm';

PRINT 'Pēc jauna <Prece> elementa pievienošanas:';
SELECT ID, XmlDati 
FROM dbo.XmlTest
WHERE Apraksts = 'Pasūtījums ar precēm';
GO

-- (b) Nomaina <Prece> ar Nosaukums="Āboli" uz "Bumbieri".
UPDATE dbo.XmlTest
SET XmlDati.modify('replace value of (/Pasutijums/Prece[@Nosaukums="Āboli"]/@Nosaukums)[1] with "Bumbieri"')
WHERE Apraksts = 'Pasūtījums ar precēm';

PRINT 'Pēc vērtības nomaiņas (Āboli uz Bumbieri):';
SELECT ID, XmlDati 
FROM dbo.XmlTest
WHERE Apraksts = 'Pasūtījums ar precēm';
GO

-- (c) Dzēš <Prece> elementu ar Nosaukums="Bumbas".
UPDATE dbo.XmlTest
SET XmlDati.modify('delete (/Pasutijums/Prece[@Nosaukums="Bumbas"])[1]')
WHERE Apraksts = 'Pasūtījums ar precēm';

PRINT 'Pēc <Prece> elementa dzēšanas (Bumbas):';
SELECT ID, XmlDati 
FROM dbo.XmlTest
WHERE Apraksts = 'Pasūtījums ar precēm';
GO

------------------------------------------------------------
-- 6. Izmanto nodes() metodi, lai pārveidotu XML datus par tabulas rindām un kolonnām.
--    Tas rezultēsies ar vairākām rindām nekā ir tabulā.
------------------------------------------------------------

SELECT T.ID, T.Apraksts,
       X.Prece.value('@ID', 'int') AS PrecesID,
       X.Prece.value('@Nosaukums', 'nvarchar(50)') AS PrecesNosaukums,
       X.Prece.value('@Cena', 'decimal(5,2)') AS Cena
FROM dbo.XmlTest T
CROSS APPLY T.XmlDati.nodes('/Pasutijums/Prece') AS X(Prece)
WHERE Apraksts = 'Pasūtījums ar precēm';
GO

DROP TABLE dbo.XmlTest;
GO

USE master;
GO

DROP DATABASE ElizaDB;
GO
