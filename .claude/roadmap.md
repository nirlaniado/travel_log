# Roadmap — 35 levels

**This table is the single source of truth for progress.** Status values:
`TODO` (not started) · `WIP` (in progress, verify not yet green) · `DONE` (verify passed).
When a level completes, change ONLY its Status cell. Per-level specs live in
`levels/level-NN-<slug>.md`.

## Phase 0 — Foundation

| # | Title | Scope | Verification (`make verify-NN`) | Status |
|---|-------|-------|--------------------------------|--------|
| 01 | Git re-init + first commit | Rebuild broken `.git`, audit `.gitignore`, commit all source | Repo valid, ≥1 commit, working tree clean, `.env`/`node_modules`/`__pycache__` not tracked | TODO |
| 02 | Verify harness + Makefile | `scripts/verify/_lib.sh`, `make verify-%` pattern, base targets | `make verify-02` prints `LEVEL 02 PASS`; `_lib.sh` sourceable; helpers work | DONE |
| 03 | GitHub repo + push | Create remote, push `main` | `git ls-remote origin` shows `main` == local HEAD | TODO |
| 04 | Pre-commit + linters | ruff+black, eslint/tsc, shellcheck, detect-secrets hooks | `pre-commit run --all-files` exits 0; staged fake secret is blocked | TODO |
| 05 | Backend test suite | pytest + httpx TestClient tests for auth/places/notes | `pytest -q` exits 0; ≥1 test file per router | TODO |
| 06 | Frontend build gate | `npm ci && npm run build` (tsc + vite) as a checked step | Build exits 0; `frontend/dist/index.html` exists | TODO |
| 07 | `/health` DB check | `/health` runs `SELECT 1`; `{status,db}`; 503 when DB down. Closes cagent ticket `cbot` | curl `/health` → `"db":"ok"`; pytest asserts 503 on DB failure | DONE |

## Phase 1 — CI

| # | Title | Scope | Verification | Status |
|---|-------|-------|--------------|--------|
| 08 | CI: lint + test | `.github/workflows/ci.yml` — pre-commit, pytest, frontend build on PR/push | `ci` workflow green on HEAD (gh/API) | TODO |
| 09 | CI: build images | CI job builds backend+frontend images | Build job green; local `docker compose build` exits 0 | TODO |
| 10 | Branch protection + PR template | Require `ci` on `main`; PR template; CODEOWNERS | API shows required check `ci` on main; template file exists | TODO |

## Phase 2 — IaC (one root module, single apply/destroy, EKS-only)

**2026-07-12 decision: this project is EKS-only — no standalone EC2 host phase.**
Levels 13/14/15/16/18 (EC2 hosts, their SSM secrets, EC2 deploy, EC2 HTTPS,
EC2 CD) are REMOVED, not just skipped — `infra/ec2.tf`, `infra/iam.tf`,
`infra/ssm.tf`, and the EC2 user-data templates no longer exist. Their
concerns are covered elsewhere: secrets go directly into the `travellog`
Helm release as sensitive Terraform values (see `infra/helm.tf`), and TLS/CD
are level 28/29's job on the EKS side.

| # | Title | Scope | Verification | Status |
|---|-------|-------|--------------|--------|
| 11 | Terraform bootstrap | `infra/` root module, S3 remote state + DynamoDB lock, pinned providers, eu-north-1 | `terraform init` + `validate` ok; state object in S3; lock table exists | DONE |
| 12 | VPC (2 AZ, no NAT) | VPC, 2 public subnets across 2 AZs, IGW, routes; SGs owned by EKS (eks.tf) + ALB (alb.tf) | Post-apply plan clean; subnets span 2 AZs; no NAT in plan | TODO |
| 13 | ~~EC2 2× t3.small~~ | REMOVED — EKS-only decision, 2026-07-12 | — | N/A |
| 14 | ~~SSM secrets~~ | REMOVED — EKS-only decision, 2026-07-12. Secrets now flow directly into the Helm release (`infra/helm.tf` `set_sensitive`) | — | N/A |
| 15 | ~~Terraform-driven EC2 deploy~~ | REMOVED — superseded by level 28 (App on EKS via helm_release) | — | N/A |
| 16 | ~~HTTPS via nip.io (EC2/Caddy)~~ | REMOVED — superseded by level 28's ALB + ACM TLS | — | N/A |
| 17 | Optional RDS module | `count=0` default; requires `enable_eks=true` (RDS has no consumer without EKS); 2-AZ subnet group; db.t3.small when enabled | Flag off → no RDS in plan; flag on (scratch, with EKS up) → backend connects, then destroy | TODO |
| 18 | ~~CD to EC2~~ | REMOVED — EKS-only decision, 2026-07-12. CD is level 29 (GitHub Actions → EKS) only | — | N/A |
| 19 | ECR | Terraform ECR repos; CI pushes tags; EKS nodes pull from ECR | `ecr describe-images` shows tag | DONE — repos created + both images pushed |

## Phase 3 — Observability v1

| # | Title | Scope | Verification | Status |
|---|-------|-------|--------------|--------|
| 20 | Structured JSON logging | JSON logs + request-id middleware | Log line parses as JSON with `request_id`, `path`, `status` | TODO |
| 21 | `/metrics` endpoint | prometheus_client: request count + latency | Counter increments across two curls of `/metrics` | TODO |
| 22 | Error tracking | Sentry free tier, DSN from SSM/env | Forced test exception is captured; DSN not hardcoded | TODO |
| 23 | Uptime monitoring | healthchecks.io / cron ping on `/health` | Monitor config present; simulated down flips status | TODO |

## Phase 4 — Kubernetes (local first, then ephemeral EKS)

| # | Title | Scope | Verification | Status |
|---|-------|-------|--------------|--------|
| 24 | kind + raw manifests | Local cluster (built via k3d); node labels/taints mirror app/data/obs design | Pods Running on intended roles; port-forward `/health` → `db:ok` | DONE |
| 25 | Helm chart | `charts/travellog` with values, nodeSelector/tolerations per role | `helm lint` ok; install on kind → `/health` ok | DONE |
| 26 | Ingress + TLS on kind | ingress-nginx + self-signed cert on `travellog.127.0.0.1.nip.io` | `curl -k https://travellog.127.0.0.1.nip.io/health` → 200 | DONE |
| 27 | Terraform EKS (ephemeral) | Control plane + 3 node groups × 2 × t3.small (app/data/obs), 2 AZs, taints+labels | Cluster ACTIVE; 6 nodes Ready with correct labels; destroy same session | TODO |
| 28 | App on EKS via helm_release | travellog chart (MySQL StatefulSet on data nodes) inside the one apply → live URL output | Fresh apply alone → internet curl `https://<lb>.nip.io/health` → 200; pods on correct groups; destroy leaves nothing | TODO |
| 29 | CD to EKS (GitHub Actions) | Push to main → build → push ECR → `helm upgrade`; OIDC role, no long-lived keys | Push rolls out new image; workflow post-deploy curl 200; `kubectl rollout status` clean | TODO |
| 30 | Prometheus/Grafana/Loki | kube-prometheus-stack + loki via terraform helm_release, pinned to obs nodes | App target `up` in Prometheus; Loki has app logs; obs pods on obs nodes | TODO |

## Phase 5 — Production hardening

| # | Title | Scope | Verification | Status |
|---|-------|-------|--------------|--------|
| 31 | Session cleanup job | Purge expired/revoked `sessions` rows (k8s CronJob / host cron) | Expired test row deleted; valid row kept | TODO |
| 32 | Prod config hardening | `cookie_secure=true` prod profile, HSTS + security headers, fail-fast config | Prod login `Set-Cookie` has `Secure`; HSTS header present; startup fails on missing secret | TODO |
| 33 | Backup restore drill | Restore latest S3 dump into fresh MySQL; assert per-table row counts | Restore script passes; counts > 0 for all four tables | TODO |
| 34 | DR rebuild drill | `terraform destroy` → `apply` → restore backup, timed, single commands only | End-to-end drill green: `/health` → `db:ok` on rebuilt stack, no manual cloud steps | TODO |
| 35 | Security scans + load test | trivy/bandit/npm-audit gates in CI; k6 smoke load test | Security job green (0 HIGH/CRIT or allowlisted); p95 under threshold | TODO |
