USE ClinicNotes;
GO

PRINT '--- ISOLATION DEMO (Patient.FullName) ---';
PRINT 'Terminal A (hold lock i 20 sek):';
PRINT 'docker exec -it clinicnotes-sql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P ''YourStrong!Passw0rd'' -C -Q "USE ClinicNotes; EXECUTE AS USER=''admin1''; BEGIN TRAN; UPDATE app.Patient SET FullName = N''UNCOMMITTED NAME'' WHERE PatientId = 1; WAITFOR DELAY ''00:00:20''; ROLLBACK; REVERT;"';
PRINT '';
PRINT 'Terminal B (dirty read):';
PRINT 'docker exec -it clinicnotes-sql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P ''YourStrong!Passw0rd'' -C -Q "USE ClinicNotes; EXECUTE AS USER=''admin1''; SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; SELECT PatientId, FullName FROM app.Patient WHERE PatientId = 1; REVERT;"';
PRINT '';
PRINT 'Terminal B (no dirty read - READ COMMITTED):';
PRINT 'docker exec -it clinicnotes-sql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P ''YourStrong!Passw0rd'' -C -Q "USE ClinicNotes; EXECUTE AS USER=''admin1''; SET TRANSACTION ISOLATION LEVEL READ COMMITTED; SELECT PatientId, FullName FROM app.Patient WHERE PatientId = 1; REVERT;"';
GO
