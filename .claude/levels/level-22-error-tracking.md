# Level 22 — Error tracking (Sentry free tier)

**Phase:** 3 Observability  |  **Scope:** Sentry SDK wired into FastAPI, DSN supplied via SSM/env, disabled when unset.  |  **Why:** Unhandled exceptions should page a dashboard, not wait for a user email. SaaS free tier = zero infra cost (self-hosted GlitchTip documented as the alternative).

## Prerequisites
Levels that must be DONE: 14, 20.

## Steps
1. Add `sentry-sdk[fastapi]`; init at startup only if `SENTRY_DSN` env is set (from SSM parameter `/travellog/sentry_dsn`); environment tag from env.
2. Add a debug-only route or management command that raises a test exception (guarded so it's off in prod config).
3. Create the Sentry project (free tier), store the DSN in SSM, trigger the test event, see it arrive.
4. Commit (DSN never in git).

## Deliverables
- Sentry init in `backend/app/main.py`/config, SSM parameter, docs note on GlitchTip alternative
- `scripts/verify/level-22.sh`: greps repo for hardcoded DSN (must find none); with `SENTRY_DSN` set, uses the SDK's transport capture in a pytest (or Sentry API if token available) to assert the forced exception is captured; with it unset, asserts the app boots clean with Sentry disabled

## Verification
- `make verify-22` → prints `LEVEL 22 PASS`, exit 0
- Done when: a forced exception shows up in Sentry and no DSN lives in the repo.

## Rollback
- Unset the SSM parameter — SDK stays dormant.
