# Travel Logs — DevOps Level Project

Full-stack app (FastAPI + MySQL + React/TS) being evolved level-by-level into an
end-to-end DevOps project on AWS. Full spec: `.claude/project-spec.md` ·
architecture: `.claude/architecture.md` · roadmap + status: `.claude/roadmap.md` ·
per-level specs: `.claude/levels/level-NN-*.md` · verify contract: `.claude/verification.md`.

## Hard invariants (always apply)

- NEVER commit `.env`, secrets, keys, or `*.tfstate`. Secrets go directly into the
  `travellog` Helm release as sensitive Terraform values (`infra/secrets.auto.tfvars`,
  gitignored) — no standalone host, so no SSM round-trip needed.
- This project is **EKS-only** — no standalone EC2 host phase (removed 2026-07-12).
- AWS region is `eu-north-1`. Instance type is **t3.small only**, max 6 instances total.
- All subnets span **2 AZs** (EKS and RDS require it). No NAT gateways — public subnets only.
- The whole cloud stack must build with a single `terraform apply` and tear down completely
  with a single `terraform destroy`. No manual cloud steps, ever.
- EKS is ephemeral: any session that applies EKS must destroy it before ending (control
  plane ≈ $0.10/hr). Every AWS level ends with its Teardown & Cost step.
- CI/CD is GitHub Actions end-to-end. No ArgoCD.

## "Implement level N" protocol

When the user says "implement level N":

1. Read `.claude/roadmap.md` row N; confirm Status is TODO or WIP.
2. Open `.claude/levels/level-NN-<slug>.md` — that file is the full spec. Do not read other levels.
3. Run each prerequisite level's verify script (`scripts/verify/level-MM.sh`).
   If any fails, stop and report which prerequisite is broken.
4. Implement the Steps; produce all Deliverables, including `scripts/verify/level-NN.sh`.
5. Run `make verify-NN`. The level is done ONLY when it prints `LEVEL NN PASS` (exit 0).
   On failure: fix, or follow the level's Rollback note. Never mark done on red.
6. Update ONLY row N's Status cell in `.claude/roadmap.md` → DONE.
7. Commit on branch `level-NN-<slug>` with message `level-NN: <summary>`. If the level
   closes a cagent ticket, run `/cagent check <id>` after verification passes.
   AWS levels: execute Teardown & Cost before ending the session.
