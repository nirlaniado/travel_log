# Level 34 — DR runbook + full rebuild drill

**Phase:** 5 Hardening  |  **Scope:** `docs/dr-runbook.md` plus a timed, scripted drill: `terraform destroy` → `terraform apply` → restore backup → app healthy. Single commands only.  |  **Why:** The final exam for the single-command invariant: the entire production environment is disposable and rebuildable from code + backups.

## Prerequisites
Levels that must be DONE: 15 (EC2 path) or 28 (EKS path), 33. **In-session-teardown level if run against EKS.**

## Steps
1. Write `docs/dr-runbook.md`: scenarios (region loss, bad deploy, data corruption), RTO/RPO statements (RPO = backup cadence), the exact command sequence, and who/what to check after.
2. `scripts/dr_drill.sh`: capture start time → `terraform destroy -auto-approve` → assert nothing left (`aws ec2 describe-instances` / `eks list-clusters` empty for the project tags) → `terraform apply -auto-approve` → wait for `/health` db:ok → run the restore path into the new DB → re-check `/health` + a data probe (row counts > 0) → print elapsed time.
3. Run the full drill once against the EC2 stack (cheaper; EKS variant optional flag). Record the measured RTO in the runbook.
4. Commit.

## Deliverables
- `docs/dr-runbook.md` (with measured RTO), `scripts/dr_drill.sh`
- `scripts/verify/level-34.sh`: asserts runbook exists with an RTO figure; asserts the drill script's last recorded run log shows all phases green (drill writes `scripts/verify/.dr_drill_last.json`); re-running the full drill is manual by design

## Verification
- `make verify-34` → prints `LEVEL 34 PASS`, exit 0
- Done when: one full destroy→rebuild→restore cycle completed hands-off, timed, and documented.

## Teardown & Cost
- The drill ENDS in a rebuilt (running) stack — destroy it afterward if the session is over. Cost = one extra apply/destroy cycle (<$1 EC2, ~$1 EKS).

## Rollback
- The drill is the rollback. If it fails midway, `terraform apply` + restore manually per the runbook.
