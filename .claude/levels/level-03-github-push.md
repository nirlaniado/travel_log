# Level 03 — GitHub repo + push

**Phase:** 0 Foundation  |  **Scope:** Create the GitHub remote and push `main`.  |  **Why:** CI (GitHub Actions), branch protection, and CD all need a remote.

## Prerequisites
Levels that must be DONE: 01, 02.

## Steps
1. If `gh` CLI is available and authenticated: `gh repo create travel_log --private --source . --push`.
2. Otherwise: ask the user to create the repo on github.com (user `nirl10`), then `git remote add origin <url>` and `git push -u origin main`.
3. Confirm the push landed.

## Deliverables
- `origin` remote configured, `main` pushed
- `scripts/verify/level-03.sh`: asserts `git remote get-url origin` is non-empty and `git ls-remote origin main` returns the same SHA as local HEAD

## Verification
- `make verify-03` → prints `LEVEL 03 PASS`, exit 0
- Done when: remote `main` HEAD == local `main` HEAD.

## Rollback
- `git remote remove origin`; delete the GitHub repo if created by mistake.
