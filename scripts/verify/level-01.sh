#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
source scripts/verify/_lib.sh

require_cmd git

git rev-parse --git-dir >/dev/null 2>&1 || fail "not a valid git repository"

commit_count=$(git rev-list --count HEAD 2>/dev/null || echo 0)
[ "$commit_count" -ge 1 ] || fail "no commits found"

[ -z "$(git status --porcelain)" ] || fail "working tree not clean"

tracked=$(git ls-files)
for forbidden in ".env" "node_modules/" "__pycache__" ".venv/" "dist/"; do
  if echo "$tracked" | grep -q "$forbidden"; then
    fail "forbidden path tracked by git: $forbidden"
  fi
done

pass 01
