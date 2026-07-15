# Level 07 — `/health` DB check (closes cagent ticket `cbot`)

**Phase:** 0 Foundation  |  **Scope:** `/health` actually verifies the database, returns `{status, db}`, 503 when the DB is down.  |  **Why:** A health check that lies ("ok" while MySQL is dead) makes every later uptime/monitoring/k8s-probe level worthless.

## Prerequisites
Levels that must be DONE: 01, 02, 05.

## Steps
1. In `backend/app/main.py`, change `/health` to run `SELECT 1` through a DB session (use `get_db`); return `{"status":"ok","db":"ok"}` on success, HTTP 503 `{"status":"degraded","db":"error"}` on failure. Keep it fast (no retries).
2. Add pytest cases: healthy path asserts `db == "ok"`; failure path (override dependency with a session that raises) asserts 503.
3. Commit.

## Deliverables
- Updated `/health` in `backend/app/main.py` + tests in `backend/tests/`
- `scripts/verify/level-07.sh`: starts the stack if needed (`docker compose up -d`), curls `/health`, asserts body contains `"db":"ok"`; also runs the two pytest health cases

## Verification
- `make verify-07` → prints `LEVEL 07 PASS`, exit 0
- Done when: live `/health` reports the DB and tests cover both paths. **Then run `/cagent check cbot`** — this level resolves that practice ticket.

## Rollback
- Revert the commit; old static `/health` returns.
