# Level 28 — App on EKS via terraform helm_release (single apply → live URL)

**Phase:** 4 Kubernetes  |  **Scope:** ingress-nginx + the travellog chart installed BY TERRAFORM (helm provider) inside the same apply; output is a live HTTPS URL.  |  **Why:** This is the single-command invariant at full scale: `terraform apply` → working app on EKS; `terraform destroy` → nothing left.

## Prerequisites
Levels that must be DONE: 25, 27. **In-session-teardown level.**

## Steps
1. Wire terraform `helm` + `kubernetes` providers to the EKS cluster (from `aws_eks_cluster` data/attributes — no manual kubeconfig step).
2. `helm_release` resources (all `count`-gated by `enable_eks`): `ingress-nginx` (NLB service), then `travellog` with `values-eks.yaml` — ECR image refs (level 19 tags), MySQL StatefulSet on data nodes (EBS PVC), app tier 2 replicas on app nodes, ingress host `travellog.<nlb-ip>.nip.io` (or `--set` from the LB hostname via data source; Let's Encrypt via cert-manager optional — self-signed acceptable here, noted in values).
3. Secrets: `kubernetes_secret` resources fed from SSM data sources — SSM stays the source of truth.
4. Prove it: from `enable_eks=false`, one `terraform apply -var enable_eks=true` → wait → curl the output URL. Then destroy. Commit.

## Deliverables
- `infra/helm.tf`, `charts/travellog/values-eks.yaml` finalized, `app_url` output
- `scripts/verify/level-28.sh`: `aws_guard`; curls the `terraform output app_url` `/health` from the internet → 200 `"db":"ok"`; `kubectl get pods -o wide` asserts backend/frontend on `role=app` nodes and mysql on `role=data`

## Verification
- `make verify-28` → prints `LEVEL 28 PASS`, exit 0
- Done when: one command produced a live app on EKS with correct scheduling — and one command removed it all (post-destroy: `aws eks list-clusters` empty, no stray LB/EBS volumes).

## Teardown & Cost
- Adds an NLB (~$0.02/hr) + EBS gp3 volume while up. **Destroy in-session** (`enable_eks=false`); verify no orphaned load balancers/volumes after destroy.

## Rollback
- `terraform apply -var enable_eks=false`.
