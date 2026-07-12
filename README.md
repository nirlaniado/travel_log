# Travel Logs

A full-stack web application for logging places you have visited, places you want to visit, and destinations you liked — with personal notes per place.

## Tech stack

| Layer     | Technology                                  |
| --------- | ------------------------------------------- |
| Frontend  | React 18 + TypeScript (Vite)                |
| Backend   | FastAPI + SQLAlchemy 2.0 + Alembic          |
| Database  | MySQL 8                                     |
| Auth      | Username/password, Argon2 password hashing  |
| Sessions  | HttpOnly cookie with opaque random token; only a SHA-256 hash of the token is stored in MySQL |

## Project structure

```
travel_log/
├── docker-compose.yml
├── .env.example
├── backend/
│   ├── app/
│   │   ├── main.py            # FastAPI app, CORS, /health
│   │   ├── config.py          # Settings from environment variables
│   │   ├── database.py        # Engine, session factory, Base
│   │   ├── models.py          # SQLAlchemy models (users, sessions, places, place_notes)
│   │   ├── schemas.py         # Pydantic request/response schemas
│   │   ├── security.py        # Argon2 hashing + session-token helpers
│   │   ├── deps.py            # Session/user dependencies (auth guard)
│   │   └── routers/
│   │       ├── auth.py        # register / login / logout / me
│   │       ├── places.py      # places CRUD + create note
│   │       └── notes.py       # update / delete note
│   ├── alembic/               # Migrations
│   ├── requirements.txt
│   └── Dockerfile
└── frontend/
    ├── src/
    │   ├── api/client.ts      # Typed fetch wrapper (credentials: include)
    │   ├── context/AuthContext.tsx
    │   ├── components/        # NavBar, PlaceCard, PlaceForm, NotesSection, ProtectedRoute
    │   ├── pages/             # Login, Register, Dashboard, AddPlace, EditPlace, PlaceDetails
    │   └── styles.css
    └── Dockerfile
```

## Quick start (Docker)

```bash
cp .env.example .env
docker compose up --build
```

- Frontend: http://localhost:5173
- API: http://localhost:8000 (docs at http://localhost:8000/docs)
- Health check: http://localhost:8000/health

Migrations run automatically when the backend container starts.

## MySQL backups to S3

S3 bucket names cannot contain underscores and must be globally unique. The requested `travelog_s3` is not valid, so this project uses `s3-travellog-nirl10` in AWS region `eu-north-1`.

Create and configure the bucket with versioning, default encryption, ownership controls, and public access blocking. The script reads `.env` by default:

```bash
./scripts/create_s3_bucket.sh
```

Create a compressed MySQL dump and upload it to S3:

```bash
./scripts/backup_mysql_to_s3.sh
```

The backup script reads MySQL and S3 settings from `.env`, then uploads both the `.sql.gz` dump and a `.sha256` checksum under `s3://<bucket>/mysql/YYYY/MM/DD/`. Use `ENV_FILE=/path/to/.env` to point either script at a different environment file.

If `mysqldump` is not installed on the host, the script falls back to `docker compose exec db mysqldump`. That requires the Compose stack to be running and Docker to be available inside the current WSL distro.

## Manual setup (without Docker)

### 1. Database

Create a MySQL database and user:

```sql
CREATE DATABASE travel_log CHARACTER SET utf8mb4;
CREATE USER 'travel'@'localhost' IDENTIFIED BY 'travel';
GRANT ALL PRIVILEGES ON travel_log.* TO 'travel'@'localhost';
```

### 2. Backend

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env          # adjust DATABASE_URL if needed
alembic upgrade head          # create tables
uvicorn app.main:app --reload # http://localhost:8000
```

### 3. Frontend

```bash
cd frontend
npm install
cp .env.example .env          # adjust VITE_API_URL if needed
npm run dev                   # http://localhost:5173
```

## API overview

| Method | Route                     | Description                          |
| ------ | ------------------------- | ------------------------------------ |
| POST   | /auth/register            | Create account (sets session cookie) |
| POST   | /auth/login               | Log in (sets session cookie)         |
| POST   | /auth/logout              | Revoke session, clear cookie         |
| GET    | /auth/me                  | Current user                         |
| GET    | /places                   | List own places (`?status=visited\|wishlist\|liked`) |
| POST   | /places                   | Create place                         |
| GET    | /places/{id}              | Place details incl. notes            |
| PUT    | /places/{id}              | Update place                         |
| DELETE | /places/{id}              | Delete place (and its notes)         |
| POST   | /places/{id}/notes        | Add note to place                    |
| PUT    | /notes/{id}               | Update note                          |
| DELETE | /notes/{id}               | Delete note                          |
| GET    | /health                   | Health check                         |

## Security design

- **Passwords** are hashed with Argon2id (`argon2-cffi`); plain text is never stored.
- **Sessions**: on login a random 256-bit token (`secrets.token_urlsafe`) is issued in an `HttpOnly`, `SameSite=Lax` cookie. The database stores only the SHA-256 hash of the token, plus expiry, revocation timestamp, user agent, and IP. A stolen database therefore cannot be used to forge session cookies. The cookie contains no user id, username, or role.
- **Logout** sets `revoked_at`, so the token is dead server-side even if the cookie survives.
- **Expiration**: sessions expire after `SESSION_LIFETIME_HOURS` (default 7 days); expired/revoked sessions are rejected.
- **Brute-force protection**: repeated failed password attempts on an account are counted in a rolling window. By default, 5 failures within 15 minutes temporarily lock login for that account for 15 minutes and return `429 Too Many Requests` with `Retry-After`.
- **CSRF**: `SameSite=Lax` cookies + strict CORS allowlist with credentials; all state-changing endpoints require JSON bodies, which cross-site HTML forms cannot send.
- **Authorization**: every place/note query is filtered by the authenticated user's id; foreign resources return 404 so ids are not enumerable.
- **Validation**: all input is validated by Pydantic (lengths, username charset, rating 1–5, lat/lon ranges, status enum).
- Set `COOKIE_SECURE=true` in production so the cookie is only sent over HTTPS.

## Notes

- Status values: `visited`, `wishlist`, `liked`.
- Rating is optional, 1–5 stars.
- To generate a new migration after changing models: `cd backend && alembic revision --autogenerate -m "message"`.
# travel_log
