# Level 13 — EC2 2× t3.small — REMOVED

**Status: N/A.** Removed 2026-07-12: this project is EKS-only. There is no
standalone EC2 host phase — `infra/ec2.tf`, `infra/iam.tf` (EC2 instance
roles), and the EC2 user-data templates no longer exist. Compute runs
exclusively on the EKS cluster (level 27).

If you want to resurrect this level, it previously defined `infra/ec2.tf`: 2
× t3.small (`app-host` + `db-host`) with docker installed via user-data, an
`aws_key_pair`, and per-host IAM roles for SSM read + ECR pull. See git
history before 2026-07-12 for the original content.
