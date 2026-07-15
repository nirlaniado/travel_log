# Level 19 — ECR: registry-based deploys

**Phase:** 2 IaC  |  **Scope:** ECR repos for backend+frontend; CI pushes tagged images; EKS nodes pull from ECR.  |  **Why:** Immutable, versioned artifacts — the same image that passed CI is the one running in prod, and the EKS phase needs a registry regardless.

## Prerequisites
Levels that must be DONE: 09.

## Steps
1. `infra/ecr.tf`: repos `travellog/backend`, `travellog/frontend`, scan-on-push, lifecycle policy keeping last 10 images, `force_delete = true` (single-command destroy invariant).
2. Extend CI (level 29's `deploy-eks.yml`): on push to main, build + tag (`git sha`) + push to ECR via the OIDC role (`infra/github-oidc.tf`).
3. EKS nodes pull from ECR via the `AmazonEC2ContainerRegistryReadOnly` managed policy attached to the node IAM role (`infra/eks.tf`) — no extra wiring needed.

## Deliverables
- `infra/ecr.tf`
- `scripts/verify/level-19.sh`: `aws_guard`; `aws ecr describe-images` shows a tag matching current main SHA for both repos

## Verification
- `make verify-19` → prints `LEVEL 19 PASS`, exit 0
- Done when: prod runs exactly the image CI built, pulled from ECR.

## Teardown & Cost
- ECR storage ~$0.10/GB-month; lifecycle policy caps it. Effectively pennies — no teardown needed.

## Status note (2026-07-12)
DONE — applied for real via a targeted `terraform apply` (4 resources: 2
repos + 2 lifecycle policies). Both `travellog/backend:latest` and
`travellog/frontend:latest` are pushed and live in ECR
(`036074394577.dkr.ecr.eu-north-1.amazonaws.com`). `scripts/verify/level-19.sh`
not yet written — `make verify-19` will fail until it exists, even though the
underlying resources are real; add it to close this out formally.

## Rollback
- `terraform destroy -target=aws_ecr_repository.backend -target=aws_ecr_repository.frontend` (removes pushed images too, since `force_delete = true`).
