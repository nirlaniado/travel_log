# Level 30 — kube-prometheus-stack + Loki on the obs nodes

**Phase:** 4 Kubernetes  |  **Scope:** Prometheus, Grafana, and Loki installed by terraform `helm_release`, pinned to the `role=obs` node group, scraping the app and shipping its logs.  |  **Why:** The observability tier gets its own nodes — metrics from level 21 and JSON logs from level 20 finally land somewhere queryable.

## Prerequisites
Levels that must be DONE: 20, 21, 28. **In-session-teardown level.**

## Steps
1. `infra/observability.tf` (`enable_eks`-gated): `helm_release` for `kube-prometheus-stack` and `loki` (single-binary mode + promtail), all components with nodeSelector/toleration for `role=obs`; modest resource requests (t3.small = 2 GB RAM — tune or the stack won't schedule).
2. ServiceMonitor (or annotations) so Prometheus scrapes the backend's `/metrics`; promtail ships container logs (the JSON access lines parse into labels).
3. Grafana: admin password from SSM; add one dashboard (requests + p95 latency from the histogram) provisioned via configmap.
4. Apply with EKS up; generate traffic; query. Verify, then destroy the cluster. Commit.

## Deliverables
- `infra/observability.tf`, ServiceMonitor/promtail values, provisioned dashboard
- `scripts/verify/level-30.sh`: port-forward Prometheus → `/api/v1/targets` shows the backend target `up`; PromQL `http_requests_total` returns series; Loki query API returns backend log lines; `kubectl get pods -n monitoring -o wide` all on `role=obs` nodes

## Verification
- `make verify-30` → prints `LEVEL 30 PASS`, exit 0
- Done when: metrics scraped, logs in Loki, dashboard renders — all scheduled on the obs pair.

## Teardown & Cost
- Runs on the existing 6 nodes (obs pair) + small EBS for Prometheus/Loki retention while up. Destroyed with the cluster (`enable_eks=false`) — confirm no orphaned volumes.

## Rollback
- Remove the two helm_release resources and re-apply.
