#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
source scripts/verify/_lib.sh

require_cmd kubectl curl

export KUBECONFIG="${KUBECONFIG:-$(k3d kubeconfig write travellog 2>/dev/null || true)}"
[ -n "${KUBECONFIG:-}" ] && [ -f "$KUBECONFIG" ] || fail "no k3d kubeconfig found — see .claude/levels/level-24-kind-manifests.md"

kubectl get deployment -n ingress-nginx ingress-nginx-controller >/dev/null 2>&1 \
  || fail "ingress-nginx controller not found in ingress-nginx namespace"
kubectl get secret travellog-tls >/dev/null 2>&1 \
  || fail "travellog-tls secret not found — generate a self-signed cert and kubectl create secret tls travellog-tls"
kubectl get ingress travellog >/dev/null 2>&1 \
  || fail "travellog ingress not found — deploy the chart with ingress.enabled=true"

HOST="https://travellog.127.0.0.1.nip.io"

code=$(curl -sk -o /tmp/level26_health.json -w '%{http_code}' "$HOST/health")
[ "$code" = "200" ] || fail "$HOST/health returned $code, expected 200"
assert_contains "$(cat /tmp/level26_health.json)" '"db":"ok"' "/health body"

code=$(curl -sk -o /dev/null -w '%{http_code}' "$HOST/api/auth/me")
[ "$code" = "401" ] || fail "$HOST/api/auth/me returned $code, expected 401 (proves /api reaches backend with prefix stripped)"

code=$(curl -sk -o /dev/null -w '%{http_code}' "$HOST/")
[ "$code" = "200" ] || fail "$HOST/ returned $code, expected 200 (frontend)"

pass 26
