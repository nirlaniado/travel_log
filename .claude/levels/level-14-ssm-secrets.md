# Level 14 — SSM secrets — REMOVED

**Status: N/A.** Removed 2026-07-12 alongside the EC2 phase (level 13):
`infra/ssm.tf` no longer exists. Its only consumer was the EC2 hosts'
user-data (fetching credentials via `aws ssm get-parameter` at boot).

Secrets now flow a different way: `infra/helm.tf` passes `mysql_user` /
`mysql_password` / `mysql_root_password` straight into the `travellog` Helm
release via `set_sensitive`, sourced from Terraform sensitive variables
(`infra/secrets.auto.tfvars`, gitignored) — no SSM round-trip needed since
there's no separate host to fetch them at boot; Terraform and the Kubernetes
Secret it creates are the only places the values live.
