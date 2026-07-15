# Level 02 — Verify harness + Makefile

**Phase:** 0 Foundation  |  **Scope:** The shared verification library, Makefile pattern rule, and base dev targets.  |  **Why:** Every later level's "done when it passes" depends on this harness existing and being trustworthy.

## Prerequisites
Levels that must be DONE: 01.

## Steps
1. Confirm `scripts/verify/_lib.sh` exists and implements the contract in `.claude/verification.md` (`fail`, `pass`, `require_cmd`, `assert_contains`, `curl_json`, `aws_guard`).
2. Confirm `Makefile` has the `verify-%` pattern rule plus `up`/`down`/`logs`/`test`/`lint`/`build` targets.
3. `chmod +x scripts/verify/*.sh`.
4. Commit.

## Deliverables
- `scripts/verify/_lib.sh`, `Makefile` (both scaffolded — verify and fix if needed)
- `scripts/verify/level-02.sh` — harness self-test (helpers work, negative assertion fails correctly, pattern rule resolves)

## Verification
- `make verify-02` → prints `LEVEL 02 PASS`, exit 0
- Done when: the self-test passes, including the negative case (an assertion that *should* fail does fail).

## Rollback
- Revert the commit; the harness has no side effects.
