# Level 32 — Prod config hardening

**Phase:** 5 Hardening  |  **Scope:** A real production profile: `cookie_secure=true`, HSTS + security headers, fail-fast on missing required config.  |  **Why:** The insecure-by-default settings (`cookie_secure=False`, default DB creds) are fine for dev but must be impossible to ship to prod accidentally.

## Prerequisites
Levels that must be DONE: 16 (HTTPS exists, so Secure cookies won't lock you out).

## Steps
1. `backend/app/config.py`: add `environment` setting (`dev`/`prod`). In prod: `cookie_secure` forced True; startup validation fails fast if `database_url` still contains the default `travel:travel` creds or required secrets are unset.
2. Security-headers middleware: `Strict-Transport-Security` (only when prod+https), `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, a conservative `Referrer-Policy`.
3. Set `ENVIRONMENT=prod` in the cloud deploy paths (user-data / values-eks) — SSM supplies real creds so validation passes there.
4. pytest both profiles. Commit.

## Deliverables
- Config profile + validation, headers middleware, tests, deploy-path env updates
- `scripts/verify/level-32.sh`: pytest asserts prod-profile login `Set-Cookie` contains `Secure` and startup raises on default creds; if a public HTTPS URL is live, `curl -I` asserts the HSTS header

## Verification
- `make verify-32` → prints `LEVEL 32 PASS`, exit 0
- Done when: prod mode cannot run with default secrets and always sets Secure cookies + HSTS.

## Rollback
- `ENVIRONMENT=dev` restores permissive local behavior; revert commit if the validation misfires.
