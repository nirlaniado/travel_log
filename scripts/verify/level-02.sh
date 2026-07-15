#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
source scripts/verify/_lib.sh

# Harness self-test: helpers behave, Makefile wiring resolves.
require_cmd make bash

assert_contains "hello world" "world" "assert_contains self-test"

( assert_contains "hello" "absent" "negative self-test" ) 2>/dev/null \
  && fail "assert_contains failed to fail on a missing needle"

[ -f Makefile ] || fail "Makefile missing"
make -n verify-99 >/dev/null 2>&1 || fail "make verify-%% pattern rule does not resolve"

pass 02
