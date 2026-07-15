# Architecture — current, evolution, end state

## NOW (Phase 0 start)

```
Laptop (WSL2)
└── docker compose
    ├── db        mysql:8.4          (volume mysql_data)
    ├── backend   FastAPI :8000      (waits for db, alembic upgrade head)
    └── frontend  nginx   :5173→80   (built React SPA)

No git history, no CI, no IaC, no tests, no monitoring.
```

## EKS-only (2026-07-12) — no standalone EC2 phase

This project moved straight from local Docker Compose to Kubernetes — first
k3d locally (levels 24-26, done), then EKS for real (levels 27-30). There was
a plain-EC2 deployment phase in earlier versions of this roadmap (levels
13/14/15/16/18); it was removed, not just skipped — see
`.claude/levels/level-13-tf-ec2.md` for why, and `.claude/roadmap.md` Phase 2
for the current level list.

## END STATE (Phase 4-5 — EKS, ephemeral, single-command)

```
$ terraform apply        # ONE command → live app (~20 min)
  VPC (2 AZ, public subnets, no NAT)
  EKS travellog-eks ── node groups (6 × t3.small):
    app-a / app-b       ← backend, frontend           label role=app
    data-a / data-b     ← MySQL StatefulSet           label+taint role=data
    obs-a / obs-b       ← Prometheus, Grafana, Loki   label+taint role=obs
  ECR (backend, frontend repos) — DONE, applied for real
  ALB (Terraform-managed security group) ── AWS Load Balancer Controller (IRSA)
    └── ACM cert (self-signed, imported) ── TLS terminates at the ALB
  Route 53 zone + alias record (practice — resolves once domain is registered)
  Secrets: Terraform sensitive vars → travellog Helm release (no SSM — no
           standalone host to fetch them at boot)
  helm_release (terraform-managed): aws-load-balancer-controller,
                                    kube-prometheus-stack, loki,
                                    travellog (charts/travellog)
  output: https://travellog.<alb-ip>.nip.io      (app live, TLS)
$ terraform destroy      # ONE command → everything gone

Ongoing CD: push to main → GitHub Actions (OIDC, no long-lived keys) → test →
            build → push to ECR → helm upgrade travellog against the cluster
Backups & DR: S3 dumps + scripted restore drill; full rebuild =
            terraform destroy → terraform apply → restore script
```

## Design rules encoded above

- 2 AZs everywhere: EKS control plane and RDS subnet groups require ≥2 AZs.
- No NAT gateway (cost): nodes/hosts sit in public subnets with public IPs,
  locked down by security groups.
- Single-command lifecycle: app + addons are terraform `helm_release` resources,
  so `apply` ends with a working URL and `destroy` leaves nothing behind.
- t3.small only, ≤6 nodes — free-plan constraint.
- GitHub Actions is the only CD mechanism (no ArgoCD).
