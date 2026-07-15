# Level 31 — Session cleanup job

**Phase:** 5 Hardening  |  **Scope:** A purge job deleting expired/revoked rows from `sessions`, runnable as a CLI command and scheduled (k8s CronJob on data nodes / host cron in EC2 mode).  |  **Why:** The `sessions` table grows forever today — a known gap the devops-client agent flags; hygiene jobs are how real prod data stays bounded.

## Prerequisites
Levels that must be DONE: 05. (25 for the CronJob wrapper.)

## Steps
1. `backend/app/cleanup.py`: delete `sessions` where `expires_at < now` OR `revoked_at IS NOT NULL AND revoked_at < now - 7d`; log deleted count (JSON). Expose as `python -m app.cleanup`.
2. pytest: seed expired + revoked + valid rows, run, assert only valid remains.
3. Schedulers: chart template `cronjob.yaml` (daily, backend image, `role=data` toleration not required — runs anywhere) gated by values; EC2 mode gets a crontab line in app-host user-data.
4. Commit.

## Deliverables
- `backend/app/cleanup.py` + test, chart CronJob template, user-data cron line
- `scripts/verify/level-31.sh`: runs the seeded pytest; if a cluster is up, asserts the CronJob exists (`kubectl get cronjob`) — otherwise checks the chart template renders it

## Verification
- `make verify-31` → prints `LEVEL 31 PASS`, exit 0
- Done when: expired rows die on schedule and valid sessions survive, proven by test.

## Rollback
- Disable the CronJob in values / remove the crontab line; the command itself is idempotent and safe.
