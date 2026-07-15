# Chaos fault catalog — travel_log

Reference for the `chaos-monkey` subagent (`~/.claude/agents/chaos-monkey.md`).
Concrete, grounded injection points for THIS project, organized by the same
categories as chaos-monkey's own scanning table. Always verify a target still
exists in its current real shape before using it — this file describes the
stable architecture, not a live snapshot; deployment context changes (k3d up,
EKS up, or neither) and file contents drift as levels get implemented.

**Hard reminder (see chaos-monkey.md for the full list): `infra/*.tf` and
`infra/policies/*` are always off-limits. No exceptions, no matter how good
a fault idea lives there.**

**Difficulty tags below** (`D1`/`D2`/`D3`) follow chaos-monkey.md's rubric:
D1 = symptom points straight at the cause (~5-10 min), D2 = symptom and cause
are one hop apart (~15-30 min), D3 = real indirection, a red herring, or a
bundled two-change incident (~30-60 min) — see the dedicated Level 3 section
at the bottom for bundle examples. A single bullet can list more than one
tag when the same target supports different fault variants at different
difficulties (e.g. an obvious version of a change vs. a subtler one).

## App logic bug (code, LOW)

- `backend/app/routers/places.py` — `list_places`: the status filter compares
  `Place.status == status_filter`; a subtly wrong operator or field would
  make filtering silently return the wrong set. **D1** if the wrong field is
  glaring in a diff/read; **D2** if the swap is between two similarly-named
  fields so it only shows up when you trace the actual query result against
  the request. Verify: `pytest
  backend/tests/test_places.py::test_filter_places_by_status -q` passes.
- `backend/app/routers/auth.py` — `_record_failed_login`'s window/threshold
  logic (`login_max_failed_attempts`, `login_failure_window_minutes`); an
  off-by-one here breaks the lockout guarantee. **D2** — the symptom (lockout
  fires too early/late) doesn't obviously point at this one function without
  reading the auth flow end to end. Verify: `pytest
  backend/tests/test_auth.py::test_login_lockout_after_max_failed_attempts -q`
  passes.
- `backend/app/deps.py` — `get_current_session`'s expiry/revocation check
  (`record.revoked_at is not None or record.expires_at <= now`); flipping a
  condition here either locks everyone out or lets revoked sessions through.
  **D1** — the symptom (everyone logged out, or logout not working) points
  directly at session validation. Verify: `pytest
  backend/tests/test_auth.py::test_logout_revokes_session_server_side -q`
  passes.
- `frontend/src/api/client.ts` — the `request()` error-parsing branch (pydantic
  `detail` array formatting); breaking this makes error messages garbled, not
  the app itself. **D1**. Verify: `cd frontend && npm run test -- client.test.ts` passes.

## Config misconfiguration (code, LOW–MEDIUM)

- `backend/app/config.py` — flip a default (e.g. `cookie_secure` default, a
  `login_*` threshold) — surfaces as a subtle behavior change, not a crash.
  **D2** — nothing crashes, so you have to notice the behavior is wrong
  before you go looking. Verify: relevant `pytest backend/tests/test_auth.py`
  case, or manual login flow check.
- `charts/travellog/values.yaml` / `values-eks.yaml` / `values-k3d.yaml` —
  wrong `backend.port`/`frontend.port` number, or a wrong `mysql.database`
  name mismatched from what the app expects — surfaces once redeployed.
  **D2** — the pod-level symptom (connection refused / unknown database) is
  one hop from the values file that actually caused it. Verify: `helm
  template` + a fresh install shows the mismatch, or (if a cluster is up)
  pods fail to connect.

## Container build bug (code, LOW)

- `backend/Dockerfile` / `frontend/Dockerfile` — break a `COPY` path or the
  `CMD`/entrypoint so the image still builds but the app doesn't actually
  start correctly. **D1** if the build itself fails (error message names the
  broken line); **D2** if it builds fine but fails only at container start,
  since you then have to run it to notice. Verify: `docker build -t
  chaos-test ./backend` (or `./frontend`) then `docker run --rm chaos-test`
  fails to serve, OR the build itself fails — either is a valid, realistic
  fault.

## Helm/K8s manifest bug (code, surfaces MEDIUM once redeployed)

- `charts/travellog/templates/backend.yaml` or `frontend.yaml` — mismatch the
  Service's `selector` against the Deployment's pod `labels` (classic real
  incident: someone renames a label on one side only). **D2** — pods look
  perfectly healthy; only `kubectl get endpoints` reveals the real problem.
  Verify: after `helm upgrade`, `kubectl get endpoints travellog-backend`
  shows no addresses even though pods are Running.
- Same files — point a `readinessProbe`/`livenessProbe` `path` at something
  that doesn't exist (e.g. `/health` → `/healthz`). **D1** — `kubectl
  describe pod` names the failing path directly. Verify: pods stay `0/1
  Running` (never Ready) after redeploy; `kubectl describe pod` shows probe
  failures.
- `charts/travellog/templates/ingress.yaml` — this file already had one real
  bug this project hit (missing `/health` rule, unstripped `/api` prefix for
  nginx) — reintroducing a similar prefix/path-routing mistake is a
  legitimately realistic fault. **D2** — you have to correlate two curl
  results (working vs. broken route) to localize it to the ingress rather
  than the backend itself. Verify: `curl <ingress host>/health` and `curl
  <ingress host>/api/auth/me` return wrong routes/404 instead of reaching
  the backend.

## CI/CD workflow bug (code, LOW — surfaces on next push)

- `.github/workflows/ci.yml` — wrong `working-directory` on one job step, or
  swap `npm run build` for `npm run test` (or similar) so the wrong thing
  runs. **D1** — the job log names the exact failing step/command. Verify:
  re-running that job locally with the same command shows the mismatch, or a
  subsequent CI run fails/passes incorrectly.
- `.github/workflows/deploy-eks.yml` — a wrong image tag reference or a
  missing `--wait` type flag change. **D2** — nothing fails loudly; you have
  to read the workflow and reason about what it would actually do on the
  next run. Verify: read the workflow and confirm the step now does the
  wrong thing (this one's riskier to "run" for real since it deploys —
  prefer reasoning/inspection-based verification here, and lean toward a
  LOW-blast-radius change like a typo'd step name rather than anything that
  would actually misfire a real deploy).

## Live pod disruption (live cluster, LOW — only if a cluster is reachable)

- `kubectl delete pod -n default -l app.kubernetes.io/component=backend`
  (deletes one, Deployment recreates it — investigate via `kubectl get
  events`/`describe` why it happened). **D1**. Verify: `kubectl get pods -n
  default -l app.kubernetes.io/component=backend` shows expected replica
  count all `Running`, 0 unexpected restarts since the incident.

## Live scale-down (live cluster, MEDIUM — never scale up)

- `kubectl scale deployment/travellog-backend -n default --replicas=0` (or
  `travellog-frontend`) — simulates a full outage of one tier. **D1** —
  `kubectl get deployment` shows `0/2` immediately, cause is obvious.
  Verify: `kubectl get deployment travellog-backend -n default` shows
  `READY 2/2` (or whatever the chart's configured replica count is) again.

## Live config/secret corruption (live cluster, LOW–MEDIUM)

- `kubectl patch configmap travellog-backend-config -n default --type merge
  -p '{"data":{"CORS_ORIGINS":"http://wrong-origin.example"}}'` — breaks
  frontend↔backend CORS after next pod restart, not immediately. **D2** — the
  browser console error (CORS) is one hop from the configmap that caused it,
  and it doesn't even manifest until something restarts the pod. Verify: the
  configmap's `CORS_ORIGINS` matches the chart's configured value again
  (`kubectl get configmap travellog-backend-config -n default -o yaml`), and
  a fresh request from the real frontend origin succeeds.
- Never corrupt `travellog-secrets`' actual MySQL credential *values* in a
  way that would require re-deriving a lost password — if touching this
  Secret at all, only flip something recoverable by re-running `helm
  upgrade` (which re-applies the correct value from Terraform's
  `set_sensitive` inputs), never something only the user's own memory could
  restore.

## Live selector/label breakage (live cluster, MEDIUM)

- `kubectl patch service travellog-frontend -n default --type merge -p
  '{"spec":{"selector":{"app.kubernetes.io/component":"wrong-value"}}}'` —
  Service stops routing to any pod. **D2** — pods are Running and Ready;
  only `kubectl get endpoints` shows the empty result that explains it.
  Verify: `kubectl get endpoints travellog-frontend -n default` shows
  addresses again (non-empty).

## Live probe breakage (live cluster, MEDIUM)

- `kubectl patch deployment travellog-backend -n default --type json -p
  '[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/wrong"}]'`
  — pods go un-Ready without crashing (classic "everything looks fine except
  nothing routes" incident). **D1** — `kubectl describe pod` names the
  failing probe path directly. Verify: `kubectl get pods -n default -l
  app.kubernetes.io/component=backend` shows `1/1 Running` (Ready) again.

## Level 3 — big mess (bundled incidents, ~30-60 min)

Two tightly-related changes forming one incident story. Fixing only one
still leaves something broken — that's intentional, it's the "a bad deploy
shipped more than one thing" lesson. Each half individually still obeys
every hard invariant (LOW/MEDIUM blast radius, reversible, no cost/data/
lockout risk) — the bundling is what raises the difficulty, not the
severity of either half.

- **"Botched CORS deploy" (code, both halves LOW–MEDIUM):** change
  `backend/app/config.py`'s CORS-origins default to a value that no longer
  matches the frontend's real origin, **and** independently change
  `charts/travellog/values.yaml` (or `values-eks.yaml`)'s CORS-related
  override to a *different* wrong value. Fixing only the code default still
  leaves a deployed override masking it (or vice versa) — the user has to
  find both the code-level default and the chart-level override before
  requests succeed end to end. Verify: `pytest backend/tests -k cors -q`
  passes (code half) AND, if a cluster is up, `helm template` /
  `kubectl get configmap travellog-backend-config -o yaml` shows the chart
  value matches the real frontend origin (chart half) — both must pass.

- **"Cascading bad rollout" (live cluster, both halves MEDIUM):**
  `kubectl patch deployment travellog-backend --type json` to break the
  readiness probe path (as in the Live probe breakage entry) **and**
  `kubectl patch configmap travellog-backend-config` to a wrong
  `CORS_ORIGINS` value (as in Live config/secret corruption) in the same
  incident. Pods go un-Ready from the probe AND, once someone restarts them
  to "fix" the probe, CORS is still broken — a realistic shape for "the on
  call engineer fixed the obvious thing and declared victory too early."
  Verify: `kubectl get pods -n default -l app.kubernetes.io/component=backend`
  shows `1/1 Running` (Ready) AND the configmap's `CORS_ORIGINS` matches the
  chart's configured value again — both must pass.

Other D3 bundles can be synthesized the same way: pick two entries from
different categories above that could plausibly share a root cause (a rushed
manual patch, a bad merge, a half-finished config change) and inject both.
Always keep it to exactly two changes — three or more stops being a
"realistic incident" and starts being an unfair scavenger hunt.

## Node-role context (for realism, not fault targets)

Pods are scheduled via labels, not something to fault-inject directly: app
tier on `role=app` nodes, MySQL StatefulSet on `role=data` (tainted), any
observability stack on `role=obs` (tainted). A believable fault can
reference this (e.g. "someone changed a nodeSelector") but never actually
touch node counts/taints/labels at the *infrastructure* level — that's
`infra/eks.tf` territory and off-limits.
