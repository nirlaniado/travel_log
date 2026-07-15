# Level 12 — VPC: 2 AZs, public subnets, no NAT

**Phase:** 2 IaC  |  **Scope:** `travellog-vpc` with 2 public subnets across 2 AZs, IGW, route table.  |  **Why:** EKS control planes and RDS subnet groups both require ≥2 AZs.

## Prerequisites
Levels that must be DONE: 11.

## Steps
1. Add `infra/vpc.tf`: VPC 10.0.0.0/16, 2 public subnets (one per AZ, via `data.aws_availability_zones`), `map_public_ip_on_launch = true`, IGW + default route. **No NAT gateway anywhere.**
2. No standalone host security groups here (this project is EKS-only, 2026-07-12) — security is owned by the EKS cluster's own security group (`eks.tf`) and the ALB's Terraform-managed security group (`alb.tf`), not by `vpc.tf`.
3. `terraform apply`; confirm idempotent plan. Commit.

## Deliverables
- `infra/vpc.tf`
- `scripts/verify/level-12.sh`: `aws_guard`; `terraform -chdir=infra plan -detailed-exitcode` == 0 (no drift); `aws ec2 describe-subnets` filtered by tag shows subnets in exactly 2 distinct AZs; `aws ec2 describe-nat-gateways` for the VPC returns none

## Verification
- `make verify-12` → prints `LEVEL 12 PASS`, exit 0
- Done when: 2-AZ public networking exists, plan is clean, zero NAT gateways.

## Teardown & Cost
- VPC/subnets/IGW/SGs/route tables are free. Leave up between sessions, or `terraform destroy` — recreation is one command.

## Rollback
- `terraform destroy -target` the vpc module or revert + apply.
