# ClinicNotes (database-eksamen) – SQL Server + Docker

Dette repo indeholder et lille “klinisk notesystem” i **Microsoft SQL Server**, hvor fokus er på:

- **Datamodel + referentiel integritet** (inkl. regel: psykolog må kun skrive noter til tildelte patienter)
- **Sikkerhed / least privilege** med roller og `EXECUTE AS OWNER`
- **Testscripts** der viser forventet OK/FAIL pr. rolle
- **Performance/tuning** (index før/efter + IO/TIME) og enkel “monitoring” via index usage stats
- **Transaktioner/ACID** (rollback-demo) + isolation-level demo (køres i to terminaler)
- **Audit** via DML-trigger + auditor-view (kun metadata)

---

## Struktur

```
docker-compose.yml
sql/
  01_schema.sql
  02_security.sql
  03_tests.sql
  05_tuning_monitoring.sql
  06_transactions_isolation.sql
  07_dml_trigger_audit.sql
  07b_fix_audit_actor.sql
  08_isolation_demo_patient.sql
```

---

## Forudsætninger

- Docker + Docker Compose
- (Valgfrit) SSMS / Azure Data Studio til at browse databasen

---

## Kom i gang (Docker)

### 1) Start SQL Server containeren

Kør fra repo-roden:

```bash
docker compose up -d
```

SQL Server bliver eksponeret på `localhost:1433`.

**Login (fra docker-compose.yml):**

- User: `sa`
- Password: `YourStrong!Passw0rd`

> Tip: Skift password før du deler repo offentligt.

---

## Kør scripts (anbefalet rækkefølge)

Du kan køre scripts direkte inde i containeren med `sqlcmd` (mssql-tools18).

> `-C` betyder “trust server certificate” (sqlcmd 18). Hvis din opsætning ikke kræver det, kan du fjerne flaget.

### 2) Schema + seed data

```bash
docker exec -it clinicnotes-sql /opt/mssql-tools18/bin/sqlcmd   -S localhost -U sa -P 'YourStrong!Passw0rd' -C   -i /scripts/01_schema.sql
```

### 3) Security (roller, users, views, procedures)

```bash
docker exec -it clinicnotes-sql /opt/mssql-tools18/bin/sqlcmd   -S localhost -U sa -P 'YourStrong!Passw0rd' -C   -i /scripts/02_security.sql
```

### 4) RBAC tests (forventede OK/FAIL)

```bash
docker exec -it clinicnotes-sql /opt/mssql-tools18/bin/sqlcmd   -S localhost -U sa -P 'YourStrong!Passw0rd' -C   -i /scripts/03_tests.sql
```

### 5) Tuning + monitoring (stort perf-datasæt + index før/efter)

```bash
docker exec -it clinicnotes-sql /opt/mssql-tools18/bin/sqlcmd   -S localhost -U sa -P 'YourStrong!Passw0rd' -C   -i /scripts/05_tuning_monitoring.sql
```

> Bemærk: Perf-seed (100.000 noter) kan tage lidt tid afhængigt af din maskine.

### 6) Transaktioner + isolation demo (ACID rollback + instruktioner til 2 terminaler)

```bash
docker exec -it clinicnotes-sql /opt/mssql-tools18/bin/sqlcmd   -S localhost -U sa -P 'YourStrong!Passw0rd' -C   -i /scripts/06_transactions_isolation.sql
```

### 7) Audit trigger + auditor-view

```bash
docker exec -it clinicnotes-sql /opt/mssql-tools18/bin/sqlcmd   -S localhost -U sa -P 'YourStrong!Passw0rd' -C   -i /scripts/07_dml_trigger_audit.sql
```

**(Valgfrit) 07b – kun hvis du vil re-deploye triggeren separat:**

```bash
docker exec -it clinicnotes-sql /opt/mssql-tools18/bin/sqlcmd   -S localhost -U sa -P 'YourStrong!Passw0rd' -C   -i /scripts/07b_fix_audit_actor.sql
```

### 8) Isolation demo på `app.Patient.FullName` (copy/paste kommandoer)

```bash
docker exec -it clinicnotes-sql /opt/mssql-tools18/bin/sqlcmd   -S localhost -U sa -P 'YourStrong!Passw0rd' -C   -i /scripts/08_isolation_demo_patient.sql
```

Scriptet printer klar tekst til **Terminal A** og **Terminal B**.

---

## Sikkerhedsmodel (kort)

**Roller:**

- `role_patient`
  - Kan kun `EXECUTE app.usp_GetMyNotes` og `app.usp_GetMyNotesTop`
- `role_psychologist`
  - Kan kun `EXECUTE app.usp_AddNote` og `app.usp_AddNoteTx`
- `role_auditor`
  - Kan kun `SELECT` på views (fx `app.v_NoteStats` og `app.v_NoteAuditSummary`)
- `role_admin`
  - Har bred adgang til schema `app` (demo)

**Vigtig regel i schema:**  
`app.Note` har en sammensat FK mod `app.Assignment (PsychologistId, PatientId)`, så **en note kun kan oprettes hvis psykologen er tildelt patienten** – selv hvis nogen forsøger at bypass’e via direkte `INSERT`.

---

## Ryd op / reset

Stop containeren:

```bash
docker compose down
```

Fuld reset inkl. volume (sletter database-data):

```bash
docker compose down -v
```

---

## Fejlfinding

- **Port 1433 i brug**: Skift port-mapping i `docker-compose.yml` (fx `"1434:1433"`).
- **Login-problemer**: Tjek at password matcher `MSSQL_SA_PASSWORD` i compose.
- **Kørsler fejler i scripts**: Kør først `01_schema.sql` og derefter `02_security.sql` igen (de er skrevet til at kunne genkøres).

---

## Git: commit + push til GitHub

Hvis du vil have alt op i repoet `database_eksamen`:

### A) Hvis du ikke har clonet repo endnu

```bash
git clone https://github.com/sabr5840/database_eksamen.git
cd database_eksamen
```

Kopiér dine filer ind (inkl. `sql/` og `docker-compose.yml`) og læg `README.md` i roden.

Så:

```bash
git add .
git status
git commit -m "Add ClinicNotes SQL scripts + docker setup"
git push -u origin main
```

### B) Hvis du allerede står i din projektmappe

```bash
git init
git remote add origin https://github.com/sabr5840/database_eksamen.git
git add .
git commit -m "Initial commit: ClinicNotes database exam"
git branch -M main
git push -u origin main
```

**Hvis `main` ikke er branch-navnet i repoet** (fx `master`), så push til den branch GitHub forventer:

```bash
git push -u origin master
```

---

Hvis du vil, kan jeg også lave en lille `.gitignore` der passer til projektet (så du ikke ved en fejl committer lokale data/volumes).
