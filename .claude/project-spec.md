# Project Spec — Travel Logs

## What this is

A full-stack Travel Logs app (users save visited/wishlist/liked places with notes),
used as the vehicle for a complete DevOps journey: git → tests → CI → Terraform →
Kubernetes (k3d locally → EKS) → observability → production hardening. **EKS-only**
— there is no standalone EC2 deployment phase (removed 2026-07-12; see
`.claude/levels/level-13-tf-ec2.md` for why). Progress is tracked as 35 numbered
levels in `roadmap.md`, each with a runnable pass/fail verification (though several
EC2-only levels are now `N/A`, not part of the active count).

## Stack facts (verified on disk)

- **Backend**: FastAPI + SQLAlchemy 2.0 + Alembic, Python 3.12 (`backend/app/`,
  `backend/requirements.txt`). Routers: `auth`, `places`, `notes`. Auth is already
  hardened: Argon2id passwords, opaque session tokens (SHA-256 hash stored in MySQL),
  login rate limiting with lockout + 429.
- **Frontend**: React 18 + TypeScript + Vite (`frontend/`), multi-stage Dockerfile →
  nginx:1.27-alpine with SPA routing (`frontend/nginx.conf`).
- **Database**: MySQL 8.4. Tables: `users`, `sessions`, `places`, `place_notes`.
- **Compose**: `docker-compose.yml` — `db` (healthcheck), `backend` (entrypoint waits
  for DB, runs `alembic upgrade head`), `frontend` (5173:80).
- **Backups**: `scripts/backup_mysql_to_s3.sh` + `scripts/create_s3_bucket.sh` →
  bucket `s3-travellog-nirl10` (eu-north-1, versioned, encrypted, public-blocked).

## Conventions

- Git branches: `level-NN-<slug>`. Commits: `level-NN: <summary>`.
- Terraform: everything under `infra/`, resources prefixed `travellog-`,
  every resource tagged `Project=travel-log`. State in S3 + DynamoDB lock.
- Verify scripts: `scripts/verify/level-NN.sh`, run via `make verify-NN`
  (contract in `verification.md`).

## Cost guardrails (free-plan account)

- **t3.small only**, never more than 6 instances/nodes total (the EKS node groups
  below). Region `eu-north-1`.
- No NAT gateways — 2 public subnets across 2 AZs; EKS nodes get public IPs,
  locked down by the cluster security group + the ALB's Terraform-managed SG
  (`infra/alb.tf`) — no standalone host security groups.
- MySQL runs in-cluster (StatefulSet on the data node group) by default. RDS is
  an opt-in module with `count = 0` default, requires `enable_eks = true` (its
  subnet group spans the 2 AZs; instance is single-AZ db.t3.small when enabled,
  destroyed after verification).
- EKS is ephemeral: apply → verify → destroy within the same session.

## End-state node layout (EKS, 6 × t3.small)

| Node group | Count | AZs | Label / taint | Runs |
|---|---|---|---|---|
| app | 2 | a+b | `role=app` (no taint) | backend, frontend |
| data | 2 | a+b | `role=data` + taint `role=data:NoSchedule` | MySQL StatefulSet |
| obs | 2 | a+b | `role=obs` + taint `role=obs:NoSchedule` | Prometheus, Grafana, Loki |

Workload placement via nodeSelector + tolerations in the Helm chart.

## cagent practice tickets

A `devops-client` practice agent issues improvement tickets tracked by `/cagent`
(ledger at `~/.claude/agents/state/devops-client-log.jsonl`). This roadmap is
complementary, not a replacement. Some levels close known tickets — **level 07
resolves ticket `cbot`** (`/health` doesn't check the DB). When a level closes a
ticket, run `/cagent check <id>` after its verification passes. Never edit the
ticket ledger by hand.

## Known gaps → levels that fix them

| Gap | Level |
|---|---|
| `.git/` broken/empty, no remote | 01, 03 |
| Zero tests (backend + frontend) | 05, 06 |
| `/health` doesn't check DB (ticket `cbot`) | 07 |
| No CI | 08–10 |
| No IaC / no cloud deploy | 11–19 |
| No logging/metrics/error tracking | 20–23 |
| No Kubernetes | 24–30 |
| No session-cleanup job (unbounded `sessions` table) | 31 |
| `cookie_secure` defaults False; no security headers | 32 |
| Backups never restore-tested | 33–34 |
| No security scanning / load testing | 35 |
