USE ClinicNotes;
GO

CREATE OR ALTER TRIGGER app.trg_Note_Audit
ON app.Note
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @actor sysname = COALESCE(TRY_CAST(SESSION_CONTEXT(N'ActorUser') AS sysname), USER_NAME());

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
