# Level 10 — Branch protection + PR template

**Phase:** 1 CI  |  **Scope:** Require `ci` to pass before merging to `main`; add PR template and CODEOWNERS.  |  **Why:** A green-checkmark culture only works if red actually blocks the merge.

## Prerequisites
Levels that must be DONE: 08.

## Steps
1. Via `gh api` (or repo Settings if no token scope): protect `main` — require status check `ci`, require branches up to date. Note: on private repos this may need GitHub Pro; if the API refuses, document that limitation in the PR template and have the verify script accept an explicit `BRANCH_PROTECTION_UNAVAILABLE=1` env acknowledgment instead.
2. Add `.github/PULL_REQUEST_TEMPLATE.md` (summary / level ref / verification evidence checklist) and `.github/CODEOWNERS` (`* @nirl10`).
3. Commit via a PR to prove the gate works.

## Deliverables
- Branch protection on `main`, `.github/PULL_REQUEST_TEMPLATE.md`, `.github/CODEOWNERS`
- `scripts/verify/level-10.sh`: asserts template + CODEOWNERS exist; queries the branch-protection API for required check `ci` (or honors the documented `BRANCH_PROTECTION_UNAVAILABLE=1` fallback with a loud warning)

## Verification
- `make verify-10` → prints `LEVEL 10 PASS`, exit 0
- Done when: a PR without green `ci` cannot merge (or the plan-limitation fallback is explicitly acknowledged).

## Rollback
- Remove the protection rule via the same API.
