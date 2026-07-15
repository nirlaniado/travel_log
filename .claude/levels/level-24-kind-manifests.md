# Level 24 — Local Kubernetes: kind + raw manifests

**Phase:** 4 Kubernetes  |  **Scope:** A kind cluster whose nodes mirror the app/data/obs design; raw manifests run the full stack locally.  |  **Why:** Learn every k8s primitive by hand, for free, before a single EKS dollar — and prove the 3-role scheduling design locally.

## Prerequisites
Levels that must be DONE: 07, 19 (images exist; local images via `kind load` also fine).

## Steps

**Actually implemented via k3d** (K3s-in-Docker), not raw `kind`/`k3s` — no
sudo was available in this environment for a real k3s systemd service, and
k3d reuses the docker permissions already in place. Functionally equivalent
for this exercise (real multi-node K3s, just orchestrated via Docker). To
reproduce or recreate the cluster:

```bash
export PATH="$HOME/.local/bin:$PATH"   # k3d binary lives here, not on system PATH
curl -sL https://github.com/k3d-io/k3d/releases/latest/download/k3d-linux-amd64 \
  -o ~/.local/bin/k3d && chmod +x ~/.local/bin/k3d   # first time only

k3d cluster create travellog \
  --agents 3 \
  --k3s-arg "--disable=traefik@server:0" \
  -p "80:80@loadbalancer" -p "443:443@loadbalancer" \
  --wait --timeout 180s

export KUBECONFIG=$(k3d kubeconfig write travellog)

kubectl label node k3d-travellog-agent-0 role=app --overwrite
kubectl label node k3d-travellog-agent-1 role=data --overwrite
kubectl label node k3d-travellog-agent-2 role=obs --overwrite
kubectl taint node k3d-travellog-agent-1 role=data:NoSchedule --overwrite
kubectl taint node k3d-travellog-agent-2 role=obs:NoSchedule --overwrite
```

1. Build the app images locally and import them (no registry needed yet):
   `docker build -t travellog/backend:local ./backend`,
   `docker build -t travellog/frontend:local --build-arg VITE_API_URL=https://travellog.127.0.0.1.nip.io/api ./frontend`,
   then `k3d image import travellog/backend:local travellog/frontend:local -c travellog`.
2. Deploy with the Helm chart (level 25) directly rather than raw manifests —
   the chart already covers Namespace-less default-ns Deployments/Services/
   Secret/StatefulSet+PVC with nodeSelector/toleration per role, so writing
   separate raw manifests here would just duplicate it. Use the
   `charts/travellog/values-k3d.yaml` overlay (nodeSelectors pinned to
   `role: app`/`role: data`) — see level 25/26 for the install command.
3. Confirm scheduling: `kubectl get pods -o wide` — backend/frontend on the
   `role=app` node, mysql on the `role=data` node.

## Deliverables
- `charts/travellog/values-k3d.yaml` (local-cluster overlay: image tags, node roles)
- `scripts/verify/level-24.sh`: `kubectl get pods -o wide` all Running; asserts mysql pod is on the `role=data` node and backend on `role=app`; port-forwards backend and curls `/health` → `"db":"ok"`

## Verification
- `make verify-24` → prints `LEVEL 24 PASS`, exit 0
- Done when: full stack runs on kind with workloads on their intended roles.

## Teardown & Cost
- Local only, $0. `k3d cluster delete travellog` when done — recreate anytime with the commands above.

## Rollback
- `k3d cluster delete travellog`.

## Status note (2026-07-11)
DONE — `make verify-24` passes. Cluster, node roles, image build/import,
scheduling, and the `/health` → `"db":"ok"` check (level 07) all verified
working end-to-end on k3d.
