# Level 35 — Security scans in CI + load test

**Phase:** 5 Hardening  |  **Scope:** trivy (images), bandit (Python), `npm audit` (frontend) as CI gates; a k6 smoke load test with a latency budget.  |  **Why:** Continuous proof that the stack stays unexploitable and fast — the roadmap's capstone.

## Prerequisites
Levels that must be DONE: 09, 21 (latency histogram makes results observable).

## Steps
1. CI `security` job: trivy image scan on both images (fail on HIGH/CRITICAL, `.trivyignore` for accepted findings with justification comments), bandit on `backend/` (severity-high fail), `npm audit --audit-level=high` in `frontend/`.
2. Fix or explicitly allowlist current findings — the job must start green honestly.
3. `loadtest/smoke.js` (k6): ramp to a modest RPS against `/health` + an authenticated places flow for 1 minute; thresholds `http_req_duration p(95)<500ms`, error rate <1%. Run locally against compose (and optionally against the cloud URL when up).
4. Wire `make loadtest`. Commit.

## Deliverables
- CI security job + `.trivyignore`, `loadtest/smoke.js`, `make loadtest`
- `scripts/verify/level-35.sh`: latest CI run's `security` job green (gh/API); runs `k6 run loadtest/smoke.js` against the local stack, exit 0 (thresholds enforce the pass/fail)

## Verification
- `make verify-35` → prints `LEVEL 35 PASS`, exit 0
- Done when: scans gate every merge and the app meets its latency budget under smoke load.

## Rollback
- Mark the security job non-required temporarily if it blocks urgent work — but re-enable before closing the level.
