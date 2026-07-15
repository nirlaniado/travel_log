#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
source scripts/verify/_lib.sh

require_cmd kubectl helm

export KUBECONFIG="${KUBECONFIG:-$(k3d kubeconfig write travellog 2>/dev/null || true)}"
[ -n "${KUBECONFIG:-}" ] && [ -f "$KUBECONFIG" ] || fail "no k3d kubeconfig found — run: k3d cluster create travellog --agents 3 --k3s-arg '--disable=traefik@server:0' -p '80:80@loadbalancer' -p '443:443@loadbalancer'"

kubectl get nodes >/dev/null 2>&1 || fail "cannot reach the k3d cluster"

for role in app data obs; do
  count=$(kubectl get nodes -l "role=$role" --no-headers 2>/dev/null | wc -l)
  [ "$count" -ge 1 ] || fail "no node labeled role=$role — see .claude/levels/level-24-kind-manifests.md"
done

app_node=$(kubectl get nodes -l role=app -o jsonpath='{.items[0].metadata.name}')
data_node=$(kubectl get nodes -l role=data -o jsonpath='{.items[0].metadata.name}')

backend_node=$(kubectl get pods -l app.kubernetes.io/instance=travellog,app.kubernetes.io/component=backend -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null) \
  || fail "travellog backend pod not found — helm install the chart first"
[ "$backend_node" = "$app_node" ] || fail "backend pod is on '$backend_node', expected the role=app node '$app_node'"

mysql_node=$(kubectl get pods -l app.kubernetes.io/instance=travellog,app.kubernetes.io/component=mysql -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null) \
  || fail "travellog mysql pod not found"
[ "$mysql_node" = "$data_node" ] || fail "mysql pod is on '$mysql_node', expected the role=data node '$data_node'"

kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=travellog --timeout=60s >/dev/null

PF_PORT=18000
kubectl port-forward svc/travellog-backend "$PF_PORT:8000" >/tmp/travellog-pf.log 2>&1 &
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

pass 24
