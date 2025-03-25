/* 1. IZVEIDOT DATUBĀZI UN PARAUGTABULAS AR RINDU ATLASI AR VIENU SAKNES ELEMENTU */
/* Izveido jaunu datubāzi "TestDB" un izmanto to */
IF DB_ID('TestDB') IS NOT NULL
    DROP DATABASE TestDB;
GO
CREATE DATABASE TestDB;
GO
USE TestDB;
GO

/* Izveido tabulu Parent */
CREATE TABLE Parent (
    ParentID INT PRIMARY KEY,
    ParentName NVARCHAR(50)
);
GO

/* Izveido tabulu Child ar ārēju atslēgu uz Parent */
CREATE TABLE Child (
    ChildID INT PRIMARY KEY,
    ParentID INT,
    ChildName NVARCHAR(50),
    CONSTRAINT FK_Parent FOREIGN KEY (ParentID) REFERENCES Parent(ParentID)
);
GO

/* Ievieto parauga datus */
INSERT INTO Parent (ParentID, ParentName)
VALUES (1, 'Alpha'), (2, 'Beta'), (3, 'Gamma'), (4, 'Delta');;
GO

INSERT INTO Child (ChildID, ParentID, ChildName)
VALUES (1, 1, 'Child_A1'),
       (2, 1, 'Child_A2'),
       (3, 2, 'Child_B1'),
       (4, 2, 'Child_B2'),
       (5, 3, 'Child_C1'),
       (6, 3, 'Child_C2'),
       (7, 4, 'Child_D1'),
       (8, 4, 'Child_D2');
GO

/* Atlasa datus ar FOR XML RAW, izmantojot ROOT opciju */
SELECT P.ParentID, P.ParentName, C.ChildID, C.ChildName
FROM Parent P
LEFT JOIN Child C ON P.ParentID = C.ParentID
FOR XML RAW, ROOT('Root');
GO

/* 2. ATLASA NO JOIN TABULĀM DATUS AR FOR XML AUTO */
/* Katrs Parent elements satur vairākus Child apakšelementus */
SELECT P.ParentID,
       P.ParentName,
       C.ChildID,
       C.ChildName
FROM Parent P
LEFT JOIN Child C ON P.ParentID = C.ParentID
FOR XML AUTO;
GO

/* 3. ATLASA DATUS AR FOR XML PATH - VIENA KOLONNA KĀ ATRIBUTS UN OTRA KĀ ELEMENTS */
SELECT ParentID AS "@ID", ParentName AS "Name"
FROM Parent
FOR XML PATH('Parent'), ROOT('Parents');
GO

/* 4. ATLASA DATUS AR APAKŠVAICĀJUMU UN TYPE DIREKTĪVU */
/* Katram Parent tiek iegūti bērnu dati kā atsevišķs XML elements */
SELECT 
    P.ParentID,
    P.ParentName,
    (
        SELECT C.ChildID, C.ChildName
        FROM Child C
        WHERE C.ParentID = P.ParentID
        FOR XML PATH('Child'), TYPE
    ) AS Children
FROM Parent P
FOR XML RAW, TYPE, ROOT('Parents');
GO

/* 5. IZVEIDO TABULU AR TIPIZĒTU XML KOLONNU UN XML SHĒMU AR DIVERĢĀMU VALIDĀCIJU */
/* Izveido XML shēmas kolekciju "MyCustomSchema" */
CREATE XML SCHEMA COLLECTION MyCustomSchema AS
N'<xs:schema attributeFormDefault="unqualified" elementFormDefault="qualified" xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xs:element name="Person">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="Profession">
          <xs:complexType>
            <xs:simpleContent>
              <xs:extension base="xs:string">
                <xs:attribute type="xs:byte" name="age"/>
                <xs:attribute type="xs:byte" name="weight"/>
              </xs:extension>
            </xs:simpleContent>
          </xs:complexType>
        </xs:element>
        <xs:element type="xs:string" name="From"/>
        <xs:element name="Interests">
          <xs:complexType>
            <xs:sequence>
              <xs:element type="xs:string" name="Sport"/>
              <xs:element type="xs:string" name="Games"/>
              <xs:element type="xs:string" name="Attitude"/>
            </xs:sequence>
            <xs:attribute type="xs:byte" name="games"/>
          </xs:complexType>
        </xs:element>
      </xs:sequence>
    </xs:complexType>
  </xs:element>
</xs:schema>';
GO

/* Izveido tabulu ar tipizētu XML kolonnu, kas izmanto MyCustomSchema */
CREATE TABLE PersonData
(
    RowID INT IDENTITY(1,1) PRIMARY KEY, 
    XMLRow XML (DOCUMENT MyCustomSchema)
);
GO

/* 5.1 Pozitīva ievade: Derīgs XML dokuments */
INSERT INTO PersonData (XMLRow)
VALUES
(N'<Person>
    <Profession age="23" weight="78">Matt Murdock</Profession>
    <From>Latvia</From>
    <Interests>
        <Sport>football</Sport>
        <Games>chess</Games>
        <Attitude>neutral</Attitude>
    </Interests>
</Person>');
GO

/* 5.2 Pozitīva ievade: Vēl viens derīgs XML dokuments */
INSERT INTO PersonData (XMLRow)
VALUES
(N'<Person>
    <Profession age="20" weight="91">Frank Castle</Profession>
    <From>France</From>
    <Interests>
        <Sport>swimming</Sport>
        <Games>pool</Games>
        <Attitude>positive</Attitude>
    </Interests>
</Person>');
GO

/* 5.3 Negatīva ievade: Divi Person elementi vienā dokumentā (nav atļauts) */
BEGIN TRY
    INSERT INTO PersonData (XMLRow)
    VALUES
    (N'<Person>
        <Profession age="20" weight="68">Adam Warlock</Profession>
        <From>France</From>
        <Interests>
            <Sport>none</Sport>
            <Games>nodus</Games>
            <Attitude>yes</Attitude>
        </Interests>
    </Person>
    <Person>
        <Profession age="23" weight="80">Peter Parker</Profession>
        <From>Latvia</From>
        <Interests>
            <Sport>sewing</Sport>
            <Games>bowling</Games>
            <Attitude>moody</Attitude>
        </Interests>
    </Person>');
END TRY
BEGIN CATCH
    PRINT 'Kļūda 5.3: ' + ERROR_MESSAGE();
END CATCH;
GO

/* 5.4 Negatīva ievade: Nepareiza elementu struktūra (piemēram, trūkst obligātā elementa) */
BEGIN TRY
    INSERT INTO PersonData (XMLRow)
    VALUES
    (N'<Person>
        <Gender>Female</Gender>
        <Profession age="23" weight="59">Tony Stark</Profession>
        <From>Latvia</From>
        <Interests>
            <Sport>running</Sport>
            <Games>none</Games>
            <Attitude>unknown</Attitude>
        </Interests>
    </Person>');
END TRY
BEGIN CATCH
    PRINT 'Kļūda 5.4: ' + ERROR_MESSAGE();
END CATCH;
GO

/* 5.5 Negatīva ievade: Nepareizs datu tips ("age" jābūt skaitlim) */
BEGIN TRY
    INSERT INTO PersonData (XMLRow)
    VALUES
    (N'<Person>
		<Profession age="twenty" weight="91">Frank Castle</Profession>
		<From>France</From>
		<Interests>
			<Sport>swimming</Sport>
			<Games>pool</Games>
			<Attitude>positive</Attitude>
		</Interests>
	</Person>');
END TRY
BEGIN CATCH
    PRINT 'Kļūda 5.5: ' + ERROR_MESSAGE();
END CATCH;
GO

USE master;
GO

DROP DATABASE TestDB;
GO