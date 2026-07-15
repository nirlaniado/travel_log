# Level 18 — CD to EC2 — REMOVED

**Status: N/A.** Removed 2026-07-12: this project is EKS-only, so there is
only one CD pipeline — level 29 (GitHub Actions → EKS, `.github/workflows/deploy-eks.yml`).

Why EC2 and EKS would have needed genuinely separate CD pipelines, for the
record: EC2 deploy is imperative (push image, then `aws ssm send-command`
telling one specific host to pull + restart); EKS deploy is declarative
(push image, then `helm upgrade` against the Kubernetes API — no host access
at all, different auth, different rollback via `helm rollback`). They don't
share enough mechanism to be one branchy workflow, which is moot now that
only one target exists.
