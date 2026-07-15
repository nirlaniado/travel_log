#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
source scripts/verify/_lib.sh

require_cmd bash

[ -x backend/.venv/bin/pytest ] || fail "backend/.venv/bin/pytest not found — pip install -r backend/requirements-dev.txt into backend/.venv"

(cd backend && .venv/bin/pytest tests/test_health.py -q) || fail "pytest tests/test_health.py failed"

# Best-effort live check against whatever's actually running (docker compose
# or a reachable k3d cluster) — skipped cleanly if neither is up.
if curl -fsS --max-time 3 http://localhost:8000/health >/tmp/level07_live_health.json 2>/dev/null; then
  assert_contains "$(cat /tmp/level07_live_health.json)" '"db":"ok"' "live /health on localhost:8000"
elif [ -n "${KUBECONFIG:-}" ] && kubectl get svc travellog-backend >/dev/null 2>&1; then
  echo "live k3d stack detected — run scripts/verify/level-24.sh / level-26.sh for the in-cluster check" >&2
else
  echo "no live stack reachable on localhost:8000 — skipping live check (pytest already passed)" >&2
fi

pass 07
