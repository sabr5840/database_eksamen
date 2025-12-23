-- 03_tests.sql
USE ClinicNotes;
GO

PRINT '--- TEST 1: patient1 (Ada, PatientId=1) ---';
EXECUTE AS USER = 'patient1';
EXEC sys.sp_set_session_context @key=N'PatientId', @value=1;

BEGIN TRY
  SELECT TOP 1 * FROM app.Note; -- forventet FAIL
  PRINT 'UNEXPECTED: patient1 kunne SELECT direkte fra app.Note';
END TRY
BEGIN CATCH
  PRINT 'OK (forventet): patient1 kan ikke SELECT direkte fra app.Note';
  PRINT ERROR_MESSAGE();
END CATCH

BEGIN TRY
  EXEC app.usp_GetMyNotes; -- forventet OK
  PRINT 'OK: patient1 kan hente egne noter via usp_GetMyNotes';
END TRY
BEGIN CATCH
  PRINT 'UNEXPECTED FAIL i usp_GetMyNotes for patient1';
  PRINT ERROR_MESSAGE();
END CATCH

REVERT;
GO

PRINT '--- TEST 2: patient2 (Bo, PatientId=2) ---';
EXECUTE AS USER = 'patient2';
EXEC sys.sp_set_session_context @key=N'PatientId', @value=2;

BEGIN TRY
  EXEC app.usp_GetMyNotes; -- forventet OK men tomt + "Rows returned: 0"
  PRINT 'OK: patient2 kan kalde usp_GetMyNotes (burde give tomt resultat + Rows returned: 0)';
END TRY
BEGIN CATCH
  PRINT 'UNEXPECTED FAIL i usp_GetMyNotes for patient2';
  PRINT ERROR_MESSAGE();
END CATCH

REVERT;
GO

PRINT '--- TEST 3: psy1 (Chen, PsychologistId=1) ---';
EXECUTE AS USER = 'psy1';
EXEC sys.sp_set_session_context @key=N'PsychologistId', @value=1;

BEGIN TRY
  EXEC app.usp_AddNote @PatientId=1, @NoteText=N'Notat til Ada (OK).'; -- forventet OK
  PRINT 'OK: psy1 kunne tilføje note til patient 1 (assigned)';
END TRY
BEGIN CATCH
  PRINT 'UNEXPECTED FAIL: psy1 kunne ikke tilføje note til patient 1';
  PRINT ERROR_MESSAGE();
END CATCH

BEGIN TRY
  EXEC app.usp_AddNote @PatientId=2, @NoteText=N'Notat til Bo (skal fejle).'; -- forventet FAIL
  PRINT 'UNEXPECTED: psy1 kunne tilføje note til patient 2 uden assignment';
END TRY
BEGIN CATCH
  PRINT 'OK (forventet): psy1 kan ikke skrive til patient 2 uden assignment';
  PRINT ERROR_MESSAGE();
END CATCH

REVERT;
GO

PRINT '--- TEST 4: auditor1 ---';
EXECUTE AS USER = 'auditor1';

BEGIN TRY
  SELECT * FROM app.v_NoteStats; -- forventet OK
  PRINT 'OK: auditor kan læse statistik-view';
END TRY
BEGIN CATCH
  PRINT 'UNEXPECTED FAIL: auditor kunne ikke læse view';
  PRINT ERROR_MESSAGE();
END CATCH

BEGIN TRY
  SELECT TOP 1 * FROM app.Note; -- forventet FAIL
  PRINT 'UNEXPECTED: auditor kunne SELECT direkte fra app.Note';
END TRY
BEGIN CATCH
  PRINT 'OK (forventet): auditor kan ikke SELECT direkte fra app.Note';
  PRINT ERROR_MESSAGE();
END CATCH

REVERT;
GO

PRINT '--- TEST 5: admin1 ---';
EXECUTE AS USER = 'admin1';

BEGIN TRY
  SELECT TOP 2 * FROM app.Note; -- forventet OK for admin
  PRINT 'OK: admin kan SELECT direkte fra app.Note';
END TRY
BEGIN CATCH
  PRINT 'UNEXPECTED FAIL: admin kunne ikke SELECT';
  PRINT ERROR_MESSAGE();
END CATCH

REVERT;
GO

PRINT '--- TEST 6: REVOKE demo (admin mister SELECT) ---';

REVOKE SELECT ON SCHEMA::app FROM role_admin;
GO

EXECUTE AS USER = 'admin1';
BEGIN TRY
  SELECT TOP 1 * FROM app.Note; -- forventet FAIL nu
  PRINT 'UNEXPECTED: admin kunne stadig SELECT';
END TRY
BEGIN CATCH
  PRINT 'OK (forventet): efter REVOKE kan admin ikke længere SELECT';
  PRINT ERROR_MESSAGE();
END CATCH
REVERT;
GO

GRANT SELECT ON SCHEMA::app TO role_admin;
GO

-------------------------------------------------------------------------------
-- NY TEST 7: Admin bypass attempt (kræver FK_Note_Assignment i schema)
-- Ideen: Admin har tabel-rettigheder, men må stadig ikke kunne oprette note for
-- (PsychologistId=1, PatientId=2), fordi der ikke findes en Assignment(1,2).
-------------------------------------------------------------------------------
PRINT '--- TEST 7: admin bypass attempt (FK skal blokere) ---';

EXECUTE AS USER = 'admin1';

BEGIN TRY
  INSERT INTO app.Note (PatientId, PsychologistId, NoteText)
  VALUES (2, 1, N'ADMIN BYPASS (should fail due to FK_Note_Assignment)');
  PRINT 'UNEXPECTED: admin kunne bypass''e assignment-reglen via direkte INSERT';
END TRY
BEGIN CATCH
  PRINT 'OK (forventet): FK_Note_Assignment forhindrede bypass';
  PRINT ERROR_MESSAGE();
END CATCH

REVERT;
GO
