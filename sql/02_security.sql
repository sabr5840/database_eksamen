-- 02_security.sql
USE ClinicNotes;
GO

-- Drop users først (gør scriptet mere robust ved genkørsel)
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'patient1') DROP USER patient1;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'patient2') DROP USER patient2;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'psy1') DROP USER psy1;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'admin1') DROP USER admin1;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'auditor1') DROP USER auditor1;
GO

-- Drop roller
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'role_patient') DROP ROLE role_patient;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'role_psychologist') DROP ROLE role_psychologist;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'role_admin') DROP ROLE role_admin;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'role_auditor') DROP ROLE role_auditor;
GO

-- Opret roller
CREATE ROLE role_patient;
CREATE ROLE role_psychologist;
CREATE ROLE role_admin;
CREATE ROLE role_auditor;
GO

-- Demo-users (uden login)
CREATE USER patient1 WITHOUT LOGIN;
CREATE USER patient2 WITHOUT LOGIN;
CREATE USER psy1 WITHOUT LOGIN;
CREATE USER admin1 WITHOUT LOGIN;
CREATE USER auditor1 WITHOUT LOGIN;
GO

-- Tilføj medlemmer til roller
ALTER ROLE role_patient ADD MEMBER patient1;
ALTER ROLE role_patient ADD MEMBER patient2;
ALTER ROLE role_psychologist ADD MEMBER psy1;
ALTER ROLE role_admin ADD MEMBER admin1;
ALTER ROLE role_auditor ADD MEMBER auditor1;
GO

-- View: auditor må kun se statistik (ikke note-tekst)
CREATE OR ALTER VIEW app.v_NoteStats AS
SELECT PatientId,
       COUNT(*) AS NoteCount,
       MIN(CreatedAt) AS FirstNote,
       MAX(CreatedAt) AS LastNote
FROM app.Note
GROUP BY PatientId;
GO

-- Patient: hent egne noter (PatientId ligger i SESSION_CONTEXT)
-- Opdateret: printer rows returned (så patient2 tydeligt viser 0)
CREATE OR ALTER PROCEDURE app.usp_GetMyNotes
WITH EXECUTE AS OWNER
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @pid INT = TRY_CAST(SESSION_CONTEXT(N'PatientId') AS INT);
  IF @pid IS NULL
    THROW 50001, 'PatientId not set in session context', 1;

  SELECT NoteId, CreatedAt, PsychologistId, NoteText
  FROM app.Note
  WHERE PatientId = @pid
  ORDER BY CreatedAt DESC;

  PRINT CONCAT('Rows returned: ', @@ROWCOUNT);
END;
GO

-- Psykolog: tilføj note til tildelt patient (PsychologistId fra SESSION_CONTEXT)
CREATE OR ALTER PROCEDURE app.usp_AddNote
  @PatientId INT,
  @NoteText NVARCHAR(MAX)
WITH EXECUTE AS OWNER
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @psyId INT = TRY_CAST(SESSION_CONTEXT(N'PsychologistId') AS INT);
  IF @psyId IS NULL
    THROW 50002, 'PsychologistId not set in session context', 1;

  IF NOT EXISTS (
    SELECT 1 FROM app.Assignment
    WHERE PsychologistId = @psyId AND PatientId = @PatientId
  )
    THROW 50003, 'Not assigned to patient', 1;

  INSERT INTO app.Note (PatientId, PsychologistId, NoteText)
  VALUES (@PatientId, @psyId, @NoteText);
END;
GO

-- Least privilege: giv kun adgang til view + execute på procs
GRANT SELECT ON app.v_NoteStats TO role_auditor;
GRANT EXECUTE ON app.usp_GetMyNotes TO role_patient;
GRANT EXECUTE ON app.usp_AddNote TO role_psychologist;
GO

-- Admin: fuld adgang (demo)
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::app TO role_admin;
GO

-- (Bevidst) INGEN direkte GRANT på app.Note/app.Patient/etc. til patient/psy/auditor
GO
