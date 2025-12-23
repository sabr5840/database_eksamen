-- 05_tuning_monitoring.sql
-- Formål:
-- 1) Skabe et dataset hvor indeks-effekten er tydelig
-- 2) Måle før/efter med STATISTICS IO/TIME
-- 3) Vise "monitoring" via index-usage stats (inkl. index der ikke har stats endnu)
--
-- NOTE:
-- Denne version bruger en separat "Perf Psychologist" og en "Perf patient" (PatientId=3),
-- så dine RBAC-tests (patient1=1, patient2=2, psy1=1) ikke bliver forstyrret af perf-data.

USE ClinicNotes;
GO

-------------------------------------------------------------------------------
-- 0) Perf-procedure (TOP N, ingen NoteText)
-------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE app.usp_GetMyNotesTop
  @Top INT = 50
WITH EXECUTE AS OWNER
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @pid INT = TRY_CAST(SESSION_CONTEXT(N'PatientId') AS INT);
  IF @pid IS NULL
    THROW 50011, 'PatientId not set in session context', 1;

  SELECT TOP (@Top)
    NoteId,
    CreatedAt,
    PsychologistId
  FROM app.Note
  WHERE PatientId = @pid
  ORDER BY CreatedAt DESC;

  PRINT CONCAT('Rows returned: ', @@ROWCOUNT);
END;
GO

-- ✅ FIX: giv patient-rollen adgang til at kalde den nye perf-procedure
GRANT EXECUTE ON app.usp_GetMyNotesTop TO role_patient;
GO

-------------------------------------------------------------------------------
-- 1) Skab realistisk perf-data
--    - sikre mindst 1000 patienter
--    - opret "Perf Psychologist"
--    - assign Perf Psychologist til en perf patient (PatientId=3)
--    - indsæt 100000 noter til perf patient (kun én gang)
-------------------------------------------------------------------------------
DECLARE @TargetPatients INT = 1000;

PRINT '--- PERF SETUP: sikre mindst 1000 patienter ---';

DECLARE @ExistingPatients INT = (SELECT COUNT(*) FROM app.Patient);
IF @ExistingPatients < @TargetPatients
BEGIN
  DECLARE @ToInsert INT = @TargetPatients - @ExistingPatients;

  ;WITH n AS (
    SELECT TOP (@ToInsert)
      ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects
  )
  INSERT INTO app.Patient (FullName)
  SELECT CONCAT(N'Perf Patient ', rn + @ExistingPatients)
  FROM n;
END

PRINT '--- PERF SETUP: opret Perf Psychologist (hvis mangler) ---';

IF NOT EXISTS (SELECT 1 FROM app.Psychologist WHERE FullName = N'Perf Psychologist')
BEGIN
  INSERT INTO app.Psychologist (FullName) VALUES (N'Perf Psychologist');
END

DECLARE @PerfPsyId INT = (
  SELECT PsychologistId
  FROM app.Psychologist
  WHERE FullName = N'Perf Psychologist'
);

DECLARE @PerfPatientId INT = 3; -- vi bruger en fast "perf patient" for ikke at påvirke tests

PRINT CONCAT('--- PERF SETUP: sikre assignment for Perf Psychologist -> PatientId=', @PerfPatientId, ' ---');

INSERT INTO app.Assignment (PsychologistId, PatientId)
SELECT @PerfPsyId, @PerfPatientId
WHERE NOT EXISTS (
  SELECT 1
  FROM app.Assignment a
  WHERE a.PsychologistId = @PerfPsyId
    AND a.PatientId = @PerfPatientId
);

PRINT '--- PERF SETUP: indsæt 100000 noter (kun én gang) ---';

IF NOT EXISTS (SELECT 1 FROM app.Note WHERE NoteText = N'PERF_SEED_MARKER_V3')
BEGIN
  -- Marker
  INSERT INTO app.Note (PatientId, PsychologistId, NoteText)
  VALUES (@PerfPatientId, @PerfPsyId, N'PERF_SEED_MARKER_V3');

  ;WITH n AS (
    SELECT TOP (100000)
      ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
  )
  INSERT INTO app.Note (PatientId, PsychologistId, CreatedAt, NoteText)
  SELECT
    @PerfPatientId AS PatientId,
    @PerfPsyId     AS PsychologistId,
    DATEADD(SECOND, rn, '2025-01-01T00:00:00') AS CreatedAt,
    CONCAT(N'Perf note #', rn) AS NoteText
  FROM n;
END
GO

-------------------------------------------------------------------------------
-- 2) Baseline: uden indeks
-------------------------------------------------------------------------------
PRINT '--- PERF BASELINE: uden indeks ---';

IF EXISTS (
  SELECT 1 FROM sys.indexes
  WHERE name = 'IX_Note_Patient_CreatedAt' AND object_id = OBJECT_ID('app.Note')
)
BEGIN
  DROP INDEX IX_Note_Patient_CreatedAt ON app.Note;
END
GO

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

EXECUTE AS USER = 'patient1';
EXEC sys.sp_set_session_context @key=N'PatientId', @value=3; -- perf patient

EXEC app.usp_GetMyNotesTop @Top = 50;

REVERT;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

-------------------------------------------------------------------------------
-- 3) Tuning: indeks der matcher filter + sortering
-------------------------------------------------------------------------------
PRINT '--- PERF TUNING: opret indeks ---';

CREATE INDEX IX_Note_Patient_CreatedAt
ON app.Note (PatientId, CreatedAt DESC)
INCLUDE (PsychologistId, NoteId);
GO

------------------------------------------------