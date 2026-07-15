# Level 26 — Ingress + TLS on kind

**Phase:** 4 Kubernetes  |  **Scope:** ingress-nginx on kind with a self-signed cert, app served at `https://travellog.127.0.0.1.nip.io`.  |  **Why:** Ingress + TLS termination is exactly how EKS will expose the app; rehearse it free.

## Prerequisites
Levels that must be DONE: 25.

## Steps

**Actually implemented via k3d** (see level 24's note) with ports `80`/`443`
mapped through k3d's built-in loadbalancer node (`-p "80:80@loadbalancer" -p
"443:443@loadbalancer"` at cluster-create time), Traefik disabled in favor of
real ingress-nginx:

```bash
export KUBECONFIG=$(k3d kubeconfig write travellog)
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.nodeSelector."role"=app \
  --wait --timeout 180s
```

1. Self-signed cert:
   ```bash
   openssl req -x509 -newkey rsa:2048 -nodes -keyout tls.key -out tls.crt -days 365 \
     -subj "/CN=travellog.127.0.0.1.nip.io" \
     -addext "subjectAltName=DNS:travellog.127.0.0.1.nip.io"
   kubectl create secret tls travellog-tls --cert=tls.crt --key=tls.key
   ```
2. Deploy with `ingress.enabled=true` in `values-k3d.yaml` (already set), host
   `travellog.127.0.0.1.nip.io`, `tls.secretName: travellog-tls`.
3. **Bug found and fixed by this rehearsal**: the original `templates/ingress.yaml`
   had no `/health` rule (fell through to the frontend catch-all) and no
   prefix-stripping for `/api` (nginx doesn't rewrite by default, so the
   backend never saw the real route). Fixed by splitting into two Ingress
   objects — `travellog-api` with `nginx.ingress.kubernetes.io/rewrite-target:
   /$2` and path `/api(/|$)(.*)`, and the plain `travellog` ingress with
   `/health` (Exact) and `/` (Prefix) — since nginx's rewrite-target annotation
   applies to the whole Ingress object, not per-path, so it can't safely share
   an object with non-regex paths. This is exactly the kind of bug this level
   exists to catch before EKS.
4. `helm upgrade --install travellog charts/travellog -f charts/travellog/values.yaml -f charts/travellog/values-k3d.yaml -f secrets.yaml`.

## Deliverables
- `charts/travellog/templates/ingress.yaml` (two-Ingress split, see above), `values-k3d.yaml`, cert-gen commands
- `scripts/verify/level-26.sh`: asserts ingress-nginx controller + `travellog-tls` secret + `travellog` ingress exist; curls `/health` (expects `"db":"ok"`), `/api/auth/me` (expects 401 — proves prefix stripping works), `/` (expects 200)

## Verification
- `make verify-26` → prints `LEVEL 26 PASS`, exit 0
- Done when: the whole app is reachable through one TLS ingress host on kind.

## Teardown & Cost
- Local only, $0. Torn down with `k3d cluster delete travellog`.

## Rollback
- Disable ingress in values; port-forward still works.

## Status note (2026-07-11)
DONE — `make verify-26` passes. Ingress, TLS, `/api` prefix-stripping, and
the `/health` → `"db":"ok"` check (level 07) all proven working end-to-end,
including a live registration request through ingress → backend → MySQL.
