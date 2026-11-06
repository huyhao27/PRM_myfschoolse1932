# backend/ : database setup + API contract tests (Node 22)

The real backend of the app is the C# portal `admin-web/` (mobile JSON API under `/api/m`, port 8088).
This folder is only tooling around it; nothing here runs in production.

| Path | Purpose |
|---|---|
| `sql/schema.sql`, `sql/seed.sql` | Tables and demo data of `FSchoolDB` |
| `sql/init.js` (`npm run db:init`) | Applies the schema, demo users (password `123456`) and demo data. Idempotent. |
| `test/*.test.js` (`npm test`) | 68 contract tests of `/api/m`: status codes, JSON shape, role visibility, rate limits |
| `sql/demo-extra.sql` | Extra demo data (run by `demo.bat`, once): 6 teachers, 34 students in 10A1/10A2/11A1, 31 parents, timetables, HK1 grades, 18 requests, club members. Leaves what the tests rely on unchanged. |
| `db.js` | SQL Server pool, used by `init.js` and by the tests to clean up rows they create |

## Setup

`scripts\setup-backend.ps1` (repo root) does all of this: SQL Server, `backend/.env` with a random DB password and `JWT_SECRET`, `npm install`, `npm run db:init`.
By hand: copy `.env.example` to `.env` and fill it in, then `npm install` and `npm run db:init`.

## Run the contract tests

Start the portal first (`admin-web\tools\run.ps1`), then `npm test`.
Defaults: `API_BASE=http://localhost:8088`, `API_PREFIX=/api/m`; override them to test another server.
The login/reset limiter is in memory: more than two full runs within 15 minutes can hit 429 until the portal restarts.

## Seed accounts (password `123456`)

| Role | Email | Phone |
|---|---|---|
| GV | gv@fschool.vn | 0901000001 |
| Manager | manager@fschool.vn | 0901000002 |
| PH | ph@fschool.vn | 0901234567 |
| HS | hs@fschool.vn | 0901000003 |
| HS (second child of the PH) | hs2@fschool.vn | 0901000004 |
| GV (teaches Anh, Văn, Sử...) | gv2@fschool.vn | 0901000005 |
