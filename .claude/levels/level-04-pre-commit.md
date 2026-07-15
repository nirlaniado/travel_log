# Level 04 — Pre-commit + linters

**Phase:** 0 Foundation  |  **Scope:** `.pre-commit-config.yaml` with ruff, black, eslint/tsc, shellcheck, detect-secrets.  |  **Why:** Catch style breaks and leaked secrets before they ever reach a commit, locally and in CI.

## Prerequisites
Levels that must be DONE: 01, 02.

## Steps
1. Add `.pre-commit-config.yaml`: ruff (lint+format or ruff+black) for `backend/`, `tsc --noEmit`/eslint hook for `frontend/`, shellcheck for `scripts/`, detect-secrets (with a generated `.secrets.baseline`).
2. `pip install pre-commit` into the backend venv (add to a `requirements-dev.txt`); `pre-commit install`.
3. Run `pre-commit run --all-files`; fix everything it flags (expect some formatting churn on first run).
4. Commit config + fixes.

## Deliverables
- `.pre-commit-config.yaml`, `.secrets.baseline`, `backend/requirements-dev.txt`
- `scripts/verify/level-04.sh`: runs `pre-commit run --all-files` (must exit 0), then a negative test — write a fake AWS key to a temp file, `git add` it, assert the detect-secrets hook blocks the commit, then clean up (the temp-file dance is the one allowed state change; it must always clean up after itself)

## Verification
- `make verify-04` → prints `LEVEL 04 PASS`, exit 0
- Done when: all hooks pass on the full tree AND a staged fake secret is rejected.

## Rollback
- `pre-commit uninstall`; revert the commit.
