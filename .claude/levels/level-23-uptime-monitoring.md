# Level 23 — Uptime monitoring

**Phase:** 3 Observability  |  **Scope:** External uptime checks against `/health` with alerting (healthchecks.io free tier, or a cron-based pinger).  |  **Why:** Ticket `cbot`'s acceptance criterion — "we find out before our users do" — needs something *outside* the box watching the box.

## Prerequisites
Levels that must be DONE: 07. (15/16 for a public URL to watch.)

## Steps
1. Preferred: healthchecks.io free account — create a check, then a cron job (on app-host via user-data, or GitHub Actions `schedule`) that curls `/health` and pings the check URL on success only; healthchecks alerts (email) when pings stop or the curl fails.
2. Alternative documented: GitHub Actions scheduled workflow curling the public `/health` and failing loudly.
3. Simulate failure once (stop the backend container) and confirm the alert path fires; restart.
4. Commit config/scripts (ping URL treated as a secret in SSM).

## Deliverables
- Monitoring cron/workflow + docs of the alert path
- `scripts/verify/level-23.sh`: asserts the monitor config exists (cron entry or workflow file); if `HC_API_KEY` provided, queries healthchecks API asserting the check exists and is "up"; dry-run mode asserts the ping script exits non-zero when pointed at a dead URL

## Verification
- `make verify-23` → prints `LEVEL 23 PASS`, exit 0
- Done when: a real outage simulation flipped the monitor to failing and back.

## Rollback
- Delete the cron/workflow; the check goes silent.
