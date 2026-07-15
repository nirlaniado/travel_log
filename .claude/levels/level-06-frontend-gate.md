# Level 06 — Frontend build + typecheck gate

**Phase:** 0 Foundation  |  **Scope:** Make `npm run build` (tsc -b + vite build) a checked, repeatable gate.  |  **Why:** The frontend has no tests; the strict-TS build is the cheapest meaningful correctness gate for CI.

## Prerequisites
Levels that must be DONE: 01, 02.

## Steps
1. Ensure `npm ci` works from a clean checkout (package-lock.json committed).
2. Fix any current `tsc`/build errors so the gate starts green.
3. Wire `make build`. Commit.

## Deliverables
- Green `npm run build` from clean state
- `scripts/verify/level-06.sh`: runs `npm run build` in `frontend/`, asserts exit 0 and `frontend/dist/index.html` exists

## Verification
- `make verify-06` → prints `LEVEL 06 PASS`, exit 0
- Done when: build is green and dist output exists.

## Rollback
- Revert the commit.
