# FSchool Backend (Node 22 + Express + SQL Server)

Flutter app -> Web API -> SQL Server. Layers: `controllers/` (AuthController), `dao/` (UserDao, all SQL), `db.js` (pool), `server.js` (exports `app`; listens only when run directly).

## Setup

1. SQL Server with database `FSchoolDB` and a login with access to it.
2. `cp .env.example .env` and fill in values (`PORT, DB_SERVER, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, JWT_SECRET`). `.env` is git-ignored.
3. `npm install`
4. `npm run db:init` - creates all tables (`sql/schema.sql`) and seeds demo users and demo data (`sql/seed.sql`: timetable, grades, requests, clubs). Idempotent.

## Run

- `npm start` - listens on `0.0.0.0:$PORT` (default 3000)
- `npm test` - node:test suite against the real database (needs `db:init` first). It restores any password it changes.

## Endpoints (JSON only, CORS enabled)

| Method | Path | Body / Header | Success | Errors |
|---|---|---|---|---|
| GET | /api/health | - | 200 `{status:"ok"}` | - |
| POST | /api/login | `{identifier, password}` (email or phone) | 200 `{token, user:{id,name,email,phone,role}}` | 400 missing/empty/non-string; 401 `{message:"Invalid credentials"}` (wrong password and unknown user are identical) |
| POST | /api/reset-password | `{identifier, newPassword}` | 200 `{message}` | 400 newPassword < 6 chars/missing; 404 user not found |
| GET | /api/me | `Authorization: Bearer <jwt>` | 200 user | 401 missing/invalid/expired |

### School features (all need `Authorization: Bearer <jwt>`)

Visibility is decided on the server by role: HS sees themself, PH sees linked children (`ParentStudent`), GV sees students of the classes they teach, Manager sees all students. `?studentId=` picks the student (PH/GV/Manager); HS and a PH with one child can omit it.

| Method | Path | Who | Notes |
|---|---|---|---|
| GET | /api/children | all | Students the account can act for |
| GET | /api/schedule | all | Weekly timetable: class of the student (HS/PH), lessons taught (GV), `?className=` (Manager) |
| GET | /api/schedule/:id | all | One lesson (room, teacher, content, prep, note) |
| GET | /api/grades?term=HK1 | all (GV/Manager need `studentId`) | Per-subject mid/final/weighted average, overall average, rank, conduct |
| GET | /api/grades/:subject | same | Score entries with type, weight, date, plus the teacher's remark |
| GET | /api/requests | all | Requests visible to the role, newest first; `?status=pending|approved|rejected` |
| GET | /api/requests/:id | all | 404 when not visible |
| POST | /api/requests | HS, PH | `{studentId, type, fromDate, toDate?, reason}`; type is one of `Xin nghỉ học`, `Xin phép đi trễ`, `Xin đổi chỗ ngồi` |
| POST | /api/requests/:id/decision | GV, Manager | `{decision: "approved"|"rejected", comment?}`; 409 if already decided |
| GET | /api/clubs?q= | all | Member count and my membership status |
| GET | /api/clubs/:id | all | Details and a preview of members |
| POST | /api/clubs/:id/join | HS | Creates a `pending` membership; 409 if one exists |

Not built yet: attachments on requests, approving club join requests, entering grades, editing the timetable.

JWT expires in 1h. Malformed JSON -> 400, unexpected errors -> 500 `{message}` (no stack traces). Email is matched case-insensitively and inputs are trimmed.

Note: `/api/reset-password` is demo-grade - anyone who knows an identifier can reset that account. A real system must verify ownership first (e.g. email OTP / reset link).

## Seed accounts (password `123456`)

| Role | Email | Phone |
|---|---|---|
| GV | gv@fschool.vn | 0901000001 |
| Manager | manager@fschool.vn | 0901000002 |
| PH | ph@fschool.vn | 0901234567 |
| HS | hs@fschool.vn | 0901000003 |
| HS (second child of the PH) | hs2@fschool.vn | 0901000004 |
| GV (teaches Anh, Văn, Sử...) | gv2@fschool.vn | 0901000005 |

From the Android emulator use `http://10.0.2.2:3000`; from a real device use the PC's LAN IP (and allow port 3000 in Windows Firewall).
