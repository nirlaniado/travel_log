# Verification harness — contract

Every level ends with a runnable pass/fail check. "Level NN is finished when it
passes the test" means exactly: `make verify-NN` exits 0 and prints `LEVEL NN PASS`.

## Script contract

Each `scripts/verify/level-NN.sh`:

- Starts with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Sources `scripts/verify/_lib.sh` for shared helpers.
- Is **idempotent and read-only**: running it never changes project or cloud state.
  It only observes (curl, git, aws describe/get, kubectl get, docker ps...).
- Is **re-runnable forever**: later levels assert prerequisites by executing earlier
  levels' scripts, and CI runs them — so a script must keep passing after its level
  is done, or fail loudly if the guarantee regressed.
- On success: prints `LEVEL NN PASS` as its last line and exits 0.
- On failure: prints a clear one-line reason to stderr and exits non-zero.
- If a check needs something unavailable in the environment (no cloud creds, no
  cluster running), it must fail with a message saying what's missing — never
  silently skip and pass.

## _lib.sh helpers

- `require_cmd <cmd>...` — fail with a clear message if a binary is missing.
- `assert_contains <haystack> <needle> <label>` — substring assertion.
- `curl_json <url>` — GET with sane timeouts, prints body, fails on non-2xx.
- `aws_guard` — asserts `aws sts get-caller-identity` works and the configured
  region is `eu-north-1`; prints a cost reminder. Call it first in any script
  that touches AWS.
- `pass <NN>` — prints `LEVEL NN PASS`.

## Make wiring

`Makefile` has a pattern rule:

```make
verify-%:
	bash scripts/verify/level-$*.sh
```

so `make verify-07` runs `scripts/verify/level-07.sh`. Zero-padded names: use
`make verify-07`, not `verify-7`.

## CI subset

CI runs every verify script that needs no cloud credentials or live cluster
(phase 0–1 scripts, plus local-only checks from later levels). Cloud-touching
scripts (11–19, 27–30, 34) run manually during their level sessions.
