-- 01_schema.sql
IF DB_ID('ClinicNotes') IS NULL
BEGIN
  CREATE DATABASE ClinicNotes;
END
GO

USE ClinicNotes;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'app')
BEGIN
  EXEC('CREATE SCHEMA app');
END
GO

-- Drop (så scriptet kan køres igen)
IF OBJECT_ID('app.Note', 'U') IS NOT NULL DROP TABLE app.Note;
IF OBJECT_ID('app.Assignment', 'U') IS NOT NULL DROP TABLE app.Assignment;
IF OBJECT_ID('app.Patient', 'U') IS NOT NULL DROP TABLE app.Patient;
IF OBJECT_ID('app.Psychologist', 'U') IS NOT NULL DROP TABLE app.Psychologist;
GO

CREATE TABLE app.Patient (
  PatientId INT IDENTITY PRIMARY KEY,
  FullName NVARCHAR(200) NOT NULL
);

CREATE TABLE app.Psychologist (
  PsychologistId INT IDENTITY PRIMARY KEY,
  FullName NVARCHAR(200) NOT NULL
);

CREATE TABLE app.Assignment (
  PsychologistId INT NOT NULL,
  PatientId INT NOT NULL,
  CONSTRAINT PK_Assignment PRIMARY KEY (PsychologistId, PatientId),
  CONSTRAINT FK_Assignment_Psychologist FOREIGN KEY (PsychologistId) REFERENCES app.Psychologist(PsychologistId),
  CONSTRAINT FK_Assignment_Patient FOREIGN KEY (PatientId) REFERENCES app.Patient(PatientId)
);

CREATE TABLE app.Note (
  NoteId INT IDENTITY PRIMARY KEY,
  PatientId INT NOT NULL,
  PsychologistId INT NOT NULL,
  CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  NoteText NVARCHAR(MAX) NOT NULL,
  CONSTRAINT FK_Note_Patient FOREIGN KEY (PatientId) REFERENCES app.Patient(PatientId),
  CONSTRAINT FK_Note_Psychologist FOREIGN KEY (PsychologistId) REFERENCES app.Psychologist(PsychologistId),

  -- NY: En note må kun oprettes hvis psykologen er assigned til patienten
  CONSTRAINT FK_Note_Assignment
    FOREIGN KEY (PsychologistId, PatientId)
    REFERENCES app.Assignment (PsychologistId, PatientId)
);

GO

-- Seed data
INSERT INTO app.Patient (FullName) VALUES (N'Ada Patient'), (N'Bo Patient');
INSERT INTO app.Psychologist (FullName) VALUES (N'Dr. Chen');

-- Chen (id=1) er tildelt Ada (id=1) men ik