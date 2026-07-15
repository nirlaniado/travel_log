# Level 01 — Git re-init + first commit

**Phase:** 0 Foundation  |  **Scope:** Rebuild the broken `.git`, audit `.gitignore`, make the first commit.  |  **Why:** Nothing else (CI, CD, GitOps) works without a real git history.

## Prerequisites
None — this is the first level.

## Steps
1. The existing `.git/` directory is empty/corrupt (`git status` says "not a git repository"). Remove it and run `git init -b main`.
2. Audit `.gitignore`: must cover `.env`, `backend/.env`, `frontend/.env`, `__pycache__/`, `*.pyc`, `.venv/`, `venv/`, `node_modules/`, `frontend/dist/`, `*.tfstate*`, `.terraform/`, editor dirs.
3. `git add -A`, then review `git status` — confirm no secrets or build artifacts are staged (check any suspicious filename's contents before committing).
4. Commit: `level-01: initial commit — full travel_log app`.

## Deliverables
- Valid `.git/` with ≥1 commit on `main`
- Updated `.gitignore` (Terraform entries added)
- `scripts/verify/level-01.sh` (already scaffolded with the harness)

## Verification
- `make verify-01` → prints `LEVEL 01 PASS`, exit 0
- Done when: `git log --oneline` shows the initial commit, working tree clean, and `git ls-files` contains no `.env`/`node_modules`/`__pycache__`/`dist` paths.

## Rollback
- `rm -rf .git` and start over — nothing else is touched.
