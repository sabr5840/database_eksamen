-- 07_dml_trigger_audit_FINAL.sql
USE ClinicNotes;
GO

-- Audit tabel (ingen fuld note-tekst til auditor; vi gemmer max 200 chars til demo)
IF OBJECT_ID('app.NoteAudit','U') IS NOT NULL DROP TABLE app.NoteAudit;
GO

CREATE TABLE app.NoteAudit (
  AuditId INT IDENTITY PRIMARY KEY,
  ActionType NVARCHAR(10) NOT NULL,  -- INSERT/UPDATE/DELETE
  NoteId INT NULL,
  PatientId INT NULL,
  PsychologistId INT NULL,
  ChangedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  ActorUser SYSNAME NOT NULL,
  OldText NVARCHAR(200) NULL,
  NewText NVARCHAR(200) NULL
);
GO

-- Trigger (FIXED): prøv SESSION_CONTEXT('ActorUser') først, ellers USER_NAME()
CREATE OR ALTER TRIGGER app.trg_Note_Audit
ON app.Note
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @actor sysname =
    COALESCE(TRY_CAST(SESSION_CONTEXT(N'ActorUser') AS sysname), USER_NAME());

  -- INSERT
  INSERT INTO app.NoteAudit(ActionType, NoteId, PatientId, PsychologistId, ChangedAt, ActorUser, OldText, NewText)
  SELECT
    'INSERT',
    i.NoteId, i.PatientId, i.PsychologistId,
    SYSUTCDATETIME(),
    @actor,
    NULL,
    LEFT(i.NoteText, 200)
  FROM inserted i
  LEFT JOIN deleted d ON d.NoteId = i.NoteId
  WHERE d.NoteId IS NULL;

  -- DELETE
  INSERT INTO app.NoteAudit(ActionType, NoteId, PatientId, PsychologistId, ChangedAt, ActorUser, OldText, NewText)
  SELECT
    'DELETE',
    d.NoteId, d.PatientId, d.PsychologistId,
    SYSUTCDATETIME(),
    @actor,
    LEFT(d.NoteText, 200),
    NULL
  FROM deleted d
  LEFT JOIN inserted i ON i.NoteId = d.NoteId
  WHERE i.NoteId IS NULL;

  -- UPDATE
  INSERT INTO app.NoteAudit(ActionType, NoteId, PatientId, PsychologistId, ChangedAt, ActorUser, OldText, NewText)
  SELECT
    'UPDATE',
    i.NoteId, i.PatientId, i.PsychologistId,
    SYSUTCDATETIME(),
    @actor,
    LEFT(d.NoteText, 200),
    LEFT(i.NoteText, 200)
  FROM inserted i
  JOIN deleted d ON d.NoteId = i.NoteId;
END;
GO

-- Audit view til auditor (kun metadata)
CREATE OR ALTER VIEW app.v_NoteAuditSummary AS
SELECT
  CAST(ChangedAt AS date) AS ChangeDate,
  ActorUser,
  ActionType,
  COUNT(*) AS ChangeCount
FROM app.NoteAudit
GROUP BY CAST(ChangedAt AS date), ActorUser, ActionType;
GO

GRANT SELECT ON app.v_NoteAuditSummary TO role_auditor;
GO

PRINT '--- AUDIT TEST (final): psy1 insert + admin update ---';

-- Ryd audit for pæn output
EXECUTE AS USER='admin1';
DELETE FROM app.NoteAudit;
REVERT;
GO

-- psy1 laver en insert (via usp_AddNote) + sætter ActorUser
EXECUTE AS USER='psy1';
EXEC sys.sp_set_session_context @key=N'Psychologist