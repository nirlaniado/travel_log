# Level 25 — Helm chart `charts/travellog`

**Phase:** 4 Kubernetes  |  **Scope:** Convert the raw manifests into one parameterized Helm chart.  |  **Why:** The chart is the deployment artifact for EKS (level 28) and for CD (level 29) — values flip it between kind and EKS.

## Prerequisites
Levels that must be DONE: 24.

## Steps
1. `charts/travellog/`: Chart.yaml, values.yaml (image repos/tags, replica counts, nodeSelector/tolerations per component, DB config, ingress on/off, storageClass), templates from the level-24 manifests with helpers for labels.
2. Defaults target kind; `values-eks.yaml` overlay stub for later (ECR image refs, 2 replicas for app tier, real storage class).
3. `helm lint`, `helm template` sanity, then `helm install travellog charts/travellog` on a fresh kind cluster — same green state as level 24.
4. Commit.

## Deliverables
- `charts/travellog/` complete chart + `values-eks.yaml` stub
- `scripts/verify/level-25.sh`: `helm lint` exit 0; `helm template` renders without error; on kind: release installed, pods Running, port-forward `/health` → `"db":"ok"`

## Verification
- `make verify-25` → prints `LEVEL 25 PASS`, exit 0
- Done when: `helm install` alone reproduces the level-24 state.

## Teardown & Cost
- Local only, $0. `helm uninstall` / `kind delete cluster`.

## Rollback
- `helm uninstall travellog`; raw manifests still exist.

## Status note (2026-07-11)
DONE — `make verify-25` passes. Chart lints, templates, and installs cleanly
on k3d (`values-k3d.yaml` overlay), including a real registration request
proven end-to-end through ingress → backend → MySQL. Also note: no separate
raw manifests were written for level 24 — the chart itself serves that
purpose, see level 24's Steps.
