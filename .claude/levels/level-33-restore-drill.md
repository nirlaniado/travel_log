# Level 33 — Backup RESTORE drill

**Phase:** 5 Hardening  |  **Scope:** A script that pulls the latest S3 dump and restores it into a fresh throwaway MySQL, asserting per-table row counts.  |  **Why:** An untested backup is a rumor. The existing `backup_mysql_to_s3.sh` uploads dumps — nothing has ever proven they restore.

## Prerequisites
Levels that must be DONE: 02. (Backups already exist via `scripts/backup_mysql_to_s3.sh`.)

## Steps
1. `scripts/restore_drill.sh`: find newest object under `s3://s3-travellog-nirl10/mysql/`, download dump + `.sha256`, verify checksum, start a scratch MySQL container (random port, no volume), restore the dump, then `SELECT COUNT(*)` from `users`, `sessions`, `places`, `place_notes` — assert each ≥ expected floor (≥0 rows but tables must EXIST; fail on missing table), print a per-table report, destroy the scratch container (trap-based cleanup).
2. Run a fresh backup first so the drill exercises today's data.
3. Commit.

## Deliverables
- `scripts/restore_drill.sh`
- `scripts/verify/level-33.sh`: runs a backup, then the drill end-to-end; asserts the report lists all four tables and checksum verification passed

## Verification
- `make verify-33` → prints `LEVEL 33 PASS`, exit 0
- Done when: today's backup demonstrably restores into a working database.

## Teardown & Cost
- Scratch container is local and auto-removed; S3 GET pennies. $0 effectively.

## Rollback
- Drill is read-only against prod data (restores into scratch only) — nothing to roll back.
