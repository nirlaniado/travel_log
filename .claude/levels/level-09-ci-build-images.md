# Level 09 — CI: build images

**Phase:** 1 CI  |  **Scope:** CI job that builds both Docker images (no push yet).  |  **Why:** Proves images build reproducibly from a clean checkout before any registry/deploy work.

## Prerequisites
Levels that must be DONE: 08.

## Steps
1. Add a `build-images` job to `ci.yml` (or a separate workflow) using buildx: build `backend/` and `frontend/` images with `--load`, no push. Give the frontend build its `VITE_API_URL` build arg.
2. Push and confirm green.

## Deliverables
- Updated workflow with the image-build job
- `scripts/verify/level-09.sh`: asserts latest `ci` run on HEAD is green AND the run's job list includes the image-build job (gh/API); also runs `docker compose build` locally, exit 0

## Verification
- `make verify-09` → prints `LEVEL 09 PASS`, exit 0
- Done when: images build in CI and locally from clean state.

## Rollback
- Remove the job from the workflow.
