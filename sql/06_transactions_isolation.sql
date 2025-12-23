-- 06_transactions_isolation.sql
USE ClinicNotes;
GO

-------------------------------------------------------------------------------
-- A) Transaction/ACID demo: Atomicity (rollback ved fejl)
-------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE app.usp_AddNoteTx
  @PatientId INT,
  @NoteText NVARCHAR(MAX),
  @ForceFail BIT = 0
WITH EXECUTE AS OWNER
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @psyId INT = TRY_CAST(SESSION_CONTEXT(N'PsychologistId') AS INT);
  IF @psyId IS NULL
    THROW 51001, 'PsychologistId not set in session context', 1;

  BEGIN TRY
    BEGIN TRAN;

    IF NOT EXISTS (
      SELECT 1 FROM app.Assignment
      WHERE PsychologistId = @psyId AND PatientId = @PatientId
    )
      THROW 51002, 'Not assigned to patient', 1;

    INSERT INTO app.Note (PatientId, PsychologistId, NoteText)
    VALUES (@PatientId, @psyId, @NoteText);

    -- Simuler fejl EFTER insert (for at bevise rollback)
    IF @ForceFail = 1
      THROW 51003, 'Simulated failure after insert (should rollback)', 1;

    COMMIT;
  END TRY
  BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW;
  END CATCH
END;
GO

-- Giv psykolog-rollen adgang til den nye procedure
GRANT EXECUTE ON app.usp_AddNoteTx TO role_psychologist;
GO

PRINT '--- TX TEST: rollback ved fejl (Atomicity) ---';

-- Tæl noter før
EXECUTE AS USER = 'admin1';
DECLARE @before INT = (SELECT COUNT(*) FROM app.Note WHERE PatientId = 1);
REVERT;

-- Forsøg at indsætte men tving fejl -> skal rollback
EXECUTE AS USER = 'psy1';
EXEC sys.sp_set_session_context @key=N'PsychologistId', @value=1;

BEGIN TRY
  EXEC app.usp_AddNoteTx @PatientId=1, @NoteText=N'TX FAIL (skal rulles tilbage)', @ForceFail=1;
  PRINT 'UNEXPECTED: usp_AddNoteTx fejlede ikke';
END TRY
BEGIN CATCH
  PRINT 'OK (forventet): procedure fejlede og rullede tilbage';
  PRINT ERROR_MESSAGE();
END CATCH

REVERT;

-- Tæl noter efter og sammenlign
EXECUTE AS USER = 'admin1';
DECLARE @after INT = (SELECT COUNT(*) FROM app.Note WHERE PatientId = 1);

IF @after = @before
  PRINT CONCAT('OK: note count uændret (', @before, ') -> rollback virkede');
ELSE
  PRINT CONCAT('UNEXPECTED: note count ændrede sig fra ', @before, ' til ', @after);

REVERT;
GO

-------------------------------------------------------------------------------
-- B) Isolation level demo (køres i 2 terminaler)
-------------------------------------------------------------------------------
PRINT '--- ISOLATION DEMO: Kør nu i to terminaler (copy/paste) ---';
PRINT 'Terminal A: start tran + update + WAITFOR (uden commit)';
PRINT 'Terminal B: READ UNCOMMITTED vs READ COMMITTED (dirty read demo)';
GO
