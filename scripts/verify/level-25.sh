#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
source scripts/verify/_lib.sh

require_cmd helm kubectl

SECRETS_FILE="${TRAVELLOG_SECRETS_FILE:-charts/travellog/secrets.yaml}"
[ -f "$SECRETS_FILE" ] || fail "no secrets values file at $SECRETS_FILE (copy charts/travellog/secrets.yaml.example, or set TRAVELLOG_SECRETS_FILE)"

helm lint charts/travellog -f charts/travellog/values.yaml -f "$SECRETS_FILE" >/dev/null \
  || fail "helm lint failed"

helm template travellog charts/travellog -f charts/travellog/values.yaml -f "$SECRETS_FILE" >/dev/null \
  || fail "helm template failed to render"

export KUBECONFIG="${KUBECONFIG:-$(k3d kubeconfig write travellog 2>/dev/null || true)}"
if [ -n "${KUBECONFIG:-}" ] && [ -f "$KUBECONFIG" ] && kubectl get nodes >/dev/null 2>&1; then
  kubectl get deployment travellog-backend >/dev/null 2>&1 || fail "chart not installed on the reachable cluster — helm install it first"
  kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=travellog --timeout=60s >/dev/null

  PF_PORT=18001
  kubectl port-forward svc/travellog-backend "$PF_PORT:8000" >/tmp/travellog-pf25.log 2>&1 &
  PF_PID=$!
  trap 'kill $PF_PID 2>/dev/null || true' EXIT

  body=""
  for _ in 1 2 3 4 5 6 7 8; do
    if body=$(curl -fsS --max-time 2 "http://localhost:$PF_PORT/health" 2>/dev/null); then
      break
    fi
    sleep 1
  done
  [ -n "$body" ] || fail "GET http://localhost:$PF_PORT/health did not respond (port-forward may not have established in time)"
  assert_contains "$body" '"db":"ok"' "/health via port-forward"
else
  echo "no reachable cluster — skipping live install check (lint/template already passed)" >&2
fi

pass 25
