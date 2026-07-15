# Level 20 — Structured JSON logging + request-id

**Phase:** 3 Observability  |  **Scope:** JSON log output and a request-id middleware in FastAPI.  |  **Why:** Grep-able, machine-parseable logs are the prerequisite for Loki at level 30 and for debugging anything in prod.

## Prerequisites
Levels that must be DONE: 05.

## Steps
1. Add a logging config (stdlib `logging` + a JSON formatter, e.g. `python-json-logger`) applied at app startup: level from env, JSON to stdout.
2. Middleware: generate/propagate `X-Request-ID`, log one line per request with `request_id`, `method`, `path`, `status`, `duration_ms`.
3. pytest: capture a request log line, `json.loads` it, assert the fields.
4. Commit.

## Deliverables
- `backend/app/logging_config.py`, middleware in `main.py`, test
- `scripts/verify/level-20.sh`: runs the log-shape pytest; also hits the running stack once and asserts the container log line for it parses as JSON (`docker compose logs backend | tail`)

## Verification
- `make verify-20` → prints `LEVEL 20 PASS`, exit 0
- Done when: every request produces exactly one parseable JSON access line with a request id.

## Rollback
- Revert the commit; uvicorn default logging returns.
