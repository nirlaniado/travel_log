#!/usr/bin/env bash
# Shared helpers for level verification scripts.
# Contract: see .claude/verification.md

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "LEVEL $1 PASS"
}

require_cmd() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || fail "required command not found: $cmd"
  done
}

assert_contains() {
  local haystack="$1" needle="$2" label="${3:-assert_contains}"
  case "$haystack" in
    *"$needle"*) ;;
    *) fail "$label: expected to find '$needle'" ;;
  esac
}

curl_json() {
  local url="$1"
  require_cmd curl
  curl --fail --silent --show-error --max-time 15 "$url" \
    || fail "GET $url did not return 2xx"
}

aws_guard() {
  require_cmd aws
  aws sts get-caller-identity >/dev/null 2>&1 \
    || fail "aws credentials not working (aws sts get-caller-identity failed)"
  local region
  region="${AWS_REGION:-$(aws configure get region 2>/dev/null || true)}"
  [ "$region" = "eu-north-1" ] || fail "AWS region must be eu-north-1 (got: '${region:-unset}')"
  echo "aws_guard: account ok, region eu-north-1. Reminder: t3.small only, teardown when done." >&2
}
