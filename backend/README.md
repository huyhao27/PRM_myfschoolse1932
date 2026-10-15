# FSchool Backend (Node 22 + Express + SQL Server)

Flutter app -> Web API -> SQL Server. Layers: `controllers/` (AuthController), `dao/` (UserDao, all SQL), `db.js` (pool), `server.js` (exports `app`; listens only when run directly).

## Setup

1. SQL Server with database `FSchoolDB` and a login with access to it.
2. `cp .env.example .env` and fill in values (`PORT, DB_SERVER, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, JWT_SECRET`). `.env` is git-ignored.
3. `npm install`
4. `npm run db:init` - creates tables (Users, Schedule, Grade) and seeds demo users. Idempotent.

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

JWT expires in 1h. Malformed JSON -> 400, unexpected errors -> 500 `{message}` (no stack traces). Email is matched case-insensitively and inputs are trimmed.

Note: `/api/reset-password` is demo-grade - anyone who knows an identifier can reset that account. A real system must verify ownership first (e.g. email OTP / reset link).

## Seed accounts (password `123456`)

| Role | Email | Phone |
|---|---|---|
| GV | gv@fschool.vn | - |
| Manager | manager@fschool.vn | - |
| PH | ph@fschool.vn | 0901234567 |
| HS | hs@fschool.vn | - |

From the Android emulator use `http://10.0.2.2:3000`; from a real device use the PC's LAN IP (and allow port 3000 in Windows Firewall).
