# Level 08 — CI: lint + test on PR

**Phase:** 1 CI  |  **Scope:** `.github/workflows/ci.yml` running pre-commit, pytest, and the frontend build on every PR and push to main.  |  **Why:** From here on, nothing merges without proof it works.

## Prerequisites
Levels that must be DONE: 03, 04, 05, 06.

## Steps
1. Create `.github/workflows/ci.yml`, workflow name `ci`, with three jobs: `lint` (pre-commit run --all-files), `backend` (setup Python 3.12, install requirements + dev, pytest), `frontend` (setup Node 20, `npm ci`, `npm run build`).
2. Cache pip and npm. Trigger on `pull_request` and `push: branches: [main]`.
3. Push and confirm a green run.

## Deliverables
- `.github/workflows/ci.yml`
- `scripts/verify/level-08.sh`: via `gh run list --workflow ci --limit 1` (or the REST API with a token) asserts the latest run for the current HEAD SHA concluded `success`; fails with clear instructions if neither gh nor a token is available

## Verification
- `make verify-08` → prints `LEVEL 08 PASS`, exit 0
- Done when: the `ci` workflow is green on HEAD with all three jobs present.

## Rollback
- Delete the workflow file; CI simply stops running.
