# Level 17 — Optional RDS module (count=0 default)

**Phase:** 2 IaC  |  **Scope:** An opt-in RDS MySQL module — 2-AZ subnet group, single-AZ db.t3.small instance — default OFF; document the container-vs-RDS tradeoff.  |  **Why:** Practice managed databases and the 2-AZ subnet-group requirement without paying for RDS all the time.

## Prerequisites
Levels that must be DONE: 12, 27 (EKS — RDS has no consumer without the cluster; `enable_rds=true` requires `enable_eks=true`, enforced by variable validation).

## Steps
1. `infra/rds.tf` gated by `local.rds_on = var.enable_rds && var.enable_eks` (drives `count`): `aws_db_subnet_group` spanning BOTH public subnets (RDS requires ≥2 AZs even for single-AZ instances), `aws_db_instance` mysql8.0 `db.t3.small`, 20 GB gp3, not publicly accessible, security group ingress from the **EKS cluster security group** only, password from a Terraform sensitive variable, `skip_final_snapshot = true` (drill env).
2. When enabled, point the `travellog` Helm release's `DATABASE_URL`-equivalent secret at the RDS endpoint instead of the in-cluster MySQL StatefulSet (chart already supports this shape — see `charts/travellog/templates/secret.yaml`).
3. Scratch test (with EKS up): `terraform apply -var enable_rds=true`, verify app connects (`/health` db:ok), then **`terraform apply -var enable_rds=false` to destroy it**. Document tradeoffs in a comment header.
4. Commit.

## Deliverables
- `infra/rds.tf` + conditional wiring
- `scripts/verify/level-17.sh`: with flag off — `terraform plan` shows zero RDS resources (cost $0 assertion); if `ENABLE_RDS_CHECK=1` (scratch mode, EKS up) — RDS endpoint reachable from the cluster and `/health` db:ok

## Verification
- `make verify-17` → prints `LEVEL 17 PASS`, exit 0
- Done when: default plan is RDS-free AND the enabled path was proven once and destroyed.

## Teardown & Cost
- db.t3.small runs ~$0.03+/hr — **never leave `enable_rds=true` after the session.** The verify default (flag off) enforces $0.

## Rollback
- `terraform apply -var enable_rds=false`.
