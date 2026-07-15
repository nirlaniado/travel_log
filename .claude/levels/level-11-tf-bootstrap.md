# Level 11 — Terraform bootstrap + remote state

**Phase:** 2 IaC  |  **Scope:** `infra/` root module with S3 remote state, DynamoDB lock, pinned providers, region `eu-north-1`.  |  **Why:** One root module from day one is what makes single-command apply/destroy possible later.

## Prerequisites
Levels that must be DONE: 01, 02. (AWS account with working credentials.)

## Steps
1. Create `infra/` with `versions.tf` (pinned terraform + aws provider), `backend.tf` (S3 backend: reuse bucket `s3-travellog-nirl10`, key `terraform/travel-log.tfstate`, DynamoDB table `travellog-tf-lock`), `providers.tf` (region `eu-north-1`, default tags `Project=travel-log`), `variables.tf`, `outputs.tf`, `main.tf`.
2. Create the lock table once (aws cli or a tiny bootstrap module with local state): on-demand billing, key `LockID`.
3. `terraform init`, `terraform validate`, `terraform apply` (empty infra is fine). Ensure `.gitignore` covers `.terraform/` and `*.tfstate*`. Commit.

## Deliverables
- `infra/` skeleton with remote state working
- `scripts/verify/level-11.sh`: `aws_guard`; `terraform -chdir=infra init -input=false` + `validate` exit 0; `aws s3api head-object` finds the state key; `aws dynamodb describe-table travellog-tf-lock` ACTIVE

## Verification
- `make verify-11` → prints `LEVEL 11 PASS`, exit 0
- Done when: validate is clean and state lives in S3 with locking.

## Teardown & Cost
- Creates: DynamoDB on-demand table (~$0 idle), one small S3 object. Nothing to tear down; both are effectively free.

## Rollback
- `terraform destroy` (no-op while empty); delete the lock table and state key if abandoning.
