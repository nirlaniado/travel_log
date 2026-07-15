# Level 27 — Terraform EKS (ephemeral, 3 node groups × 2 × t3.small)

**Phase:** 4 Kubernetes  |  **Scope:** EKS cluster in the existing 2-AZ VPC with node groups `app`/`data`/`obs`, 2 × t3.small each, labeled and tainted.  |  **Why:** The real cluster, shaped exactly like the kind rehearsal — six nodes, workloads separated.

## Prerequisites
Levels that must be DONE: 12, 19, 26. **This is an in-session-teardown level.**

## Steps
1. `infra/eks.tf` (gated by `var.enable_eks`, default `false`, like RDS): EKS cluster `travellog-eks` (public endpoint, both subnets), IAM roles, and three managed node groups — `app` (labels `role=app`), `data` (labels+taint `role=data:NoSchedule`), `obs` (labels+taint `role=obs:NoSchedule`) — each `desired=2`, `instance_types=["t3.small"]`, one per AZ spread. Total exactly 6 nodes.
2. Add EBS CSI addon (data tier PVCs) + VPC CNI/coredns/kube-proxy addons.
3. `terraform apply -var enable_eks=true` (~15 min); `aws eks update-kubeconfig`; inspect nodes.
4. Run verify, then **`terraform apply -var enable_eks=false`** (destroys cluster + nodes) before ending the session. Commit.

## Deliverables
- `infra/eks.tf` + variables/outputs (cluster name, endpoint)
- `scripts/verify/level-27.sh`: `aws_guard`; cluster status ACTIVE; `kubectl get nodes` shows exactly 6 Ready nodes, all t3.small, labels `role∈{app,data,obs}` with 2 each across 2 AZs; taints present on data/obs

## Verification
- `make verify-27` → prints `LEVEL 27 PASS`, exit 0
- Done when: the 6-node labeled/tainted cluster is proven — then destroyed.

## Teardown & Cost
- Control plane ~$0.10/hr + 6 × t3.small while up. **Mandatory: `enable_eks=false` apply in the same session.** A full session (apply→verify→destroy) costs well under $1.

## Rollback
- `terraform apply -var enable_eks=false` removes everything EKS.
