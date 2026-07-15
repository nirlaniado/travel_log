# Level 16 — HTTPS via nip.io (EC2/Caddy) — REMOVED

**Status: N/A.** Removed 2026-07-12 alongside the EC2 phase. TLS termination
is now the ALB's job: level 28 imports a self-signed cert into ACM and
terminates HTTPS at the Application Load Balancer (see `infra/alb.tf`,
`infra/helm.tf`), with an ALB security group that's explicit Terraform (not
the AWS Load Balancer Controller's default). The nip.io hostname trick lives
on — it's just derived from the ALB's IP now instead of an EC2 instance's.
