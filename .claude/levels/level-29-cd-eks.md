# Level 29 — CD to EKS via GitHub Actions

**Phase:** 4 Kubernetes  |  **Scope:** Push to main → CI builds+pushes image to ECR → workflow runs `helm upgrade` against EKS; OIDC role, no long-lived keys.  |  **Why:** GitHub Actions is this project's CD end-to-end (no ArgoCD) — merged code must reach the cluster automatically.

## Prerequisites
Levels that must be DONE: 18, 19, 28. **Requires the EKS stack up for the live test (in-session teardown still applies).**

## Steps
1. Extend the OIDC role (level 18) with `eks:DescribeCluster`; map the role into the cluster's access entries (`infra/eks.tf` access entry with a namespaced RBAC group allowed to upgrade the travellog release).
2. `.github/workflows/deploy-eks.yml` on push to main (gated on `ci` green): configure AWS via OIDC → `aws eks update-kubeconfig` → `helm upgrade travellog charts/travellog -f values-eks.yaml --set image.tag=${{ github.sha }} --wait`.
3. Post-deploy step: `kubectl rollout status` both deployments + curl the public `/health`, fail red otherwise.
4. With EKS up, push a visible change to main and watch it roll out. Commit. Destroy the cluster after.

## Deliverables
- `.github/workflows/deploy-eks.yml`, EKS access entry + RBAC in terraform
- `scripts/verify/level-29.sh`: latest `deploy-eks` run green with rollout+smoke steps passed (gh/API); running backend pod's image tag == latest main SHA (`kubectl get pod -o jsonpath` vs `git rev-parse origin/main`)

## Verification
- `make verify-29` → prints `LEVEL 29 PASS`, exit 0
- Done when: a push to main lands on EKS with a clean rollout, keylessly.

## Teardown & Cost
- No new billable resources beyond the running cluster. The workflow simply fails red while EKS is destroyed — expected between sessions.

## Rollback
- `helm rollback travellog` (workflow keeps history); disable the workflow file.
