# Level 05 — Backend test suite (pytest)

**Phase:** 0 Foundation  |  **Scope:** pytest + TestClient suite covering auth, places, and notes routers.  |  **Why:** CI without tests gates nothing; every later deploy level relies on this suite as its regression net.

## Prerequisites
Levels that must be DONE: 01, 02.

## Steps
1. Add `pytest` + `httpx` to `backend/requirements-dev.txt`.
2. Create `backend/tests/` with `conftest.py` that overrides `get_db` with an ephemeral database (SQLite in-memory with `StaticPool`, or a throwaway MySQL container — pick SQLite for speed; models are compatible).
3. Write tests per router: auth (register, duplicate 409, login ok/bad 401, lockout 429, me, logout revocation), places (CRUD, status filter, cross-user 404), notes (create/update/delete, cross-user 404). Reuse the flows already proven in the original smoke test.
4. Wire `make test`. Commit.

## Deliverables
- `backend/tests/{conftest.py,test_auth.py,test_places.py,test_notes.py}`
- `scripts/verify/level-05.sh`: runs pytest, asserts exit 0 and that all three `test_*.py` router files exist

## Verification
- `make verify-05` → prints `LEVEL 05 PASS`, exit 0
- Done when: `pytest -q` is green with ≥1 test file per router.

## Rollback
- Tests are additive; revert the commit.
