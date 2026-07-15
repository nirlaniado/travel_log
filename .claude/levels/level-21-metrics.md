# Level 21 — `/metrics` endpoint (prometheus_client)

**Phase:** 3 Observability  |  **Scope:** Prometheus metrics: request counter + latency histogram, exposed at `/metrics`.  |  **Why:** Level 30's Prometheus needs something to scrape; this is the app-side half.

## Prerequisites
Levels that must be DONE: 20.

## Steps
1. Add `prometheus_client` to requirements; instrument via middleware: `http_requests_total{method,path,status}` counter and `http_request_duration_seconds` histogram (normalize path templates, not raw URLs, to bound cardinality).
2. Mount `/metrics` (Prometheus text format). Exclude `/metrics` itself and `/health` from instrumentation noise if desired.
3. pytest: two requests → counter delta == 2.
4. Commit.

## Deliverables
- Metrics middleware + `/metrics` route, test
- `scripts/verify/level-21.sh`: curls an app endpoint twice, then `/metrics`, asserts `http_requests_total` present and increased between two samples

## Verification
- `make verify-21` → prints `LEVEL 21 PASS`, exit 0
- Done when: `/metrics` serves counters/histograms that actually move.

## Rollback
- Revert the commit.
