variable "aws_region" {
  description = "AWS region — must be eu-north-1 per project invariants."
  type        = string
  default     = "eu-north-1"

  validation {
    condition     = var.aws_region == "eu-north-1"
    error_message = "This project is pinned to eu-north-1 (see .claude/project-spec.md)."
  }
}

variable "instance_type" {
  description = "EKS node instance type — must be t3.small per free-plan budget guardrail."
  type        = string
  default     = "t3.small"

  validation {
    condition     = var.instance_type == "t3.small"
    error_message = "This project is limited to t3.small instances (see .claude/project-spec.md)."
  }
}

# --- App config (non-secret — mirrors .env.example / charts/travellog/values.yaml) ---

variable "mysql_database" {
  type    = string
  default = "travel_log"
}

# --- Secrets (sensitive — set via secrets.auto.tfvars, gitignored, see secrets.auto.tfvars.example) ---

variable "mysql_user" {
  type      = string
  sensitive = true
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
  default   = "" # required only when enable_eks && enable_observability
}

variable "mysql_password" {
  type      = string
  sensitive = true
}

variable "mysql_root_password" {
  type      = string
  sensitive = true
}

# --- Images (level 19 — ECR; empty until you build+push at least once) ---

variable "backend_image_tag" {
  type    = string
  default = "latest"
}

variable "frontend_image_tag" {
  type    = string
  default = "latest"
}

# --- Cluster toggle ---
# This project is EKS-only (no standalone EC2 host phase). EKS is still
# EPHEMERAL: apply, verify, destroy in the same session (~$0.10/hr control
# plane + 6 × t3.small while up).

variable "enable_eks" {
  description = "Run the EKS cluster (6 × t3.small: app/data/obs node groups)."
  type        = bool
  default     = false
}

variable "eks_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.33"
}

variable "enable_observability" {
  description = "Install kube-prometheus-stack + Loki on the obs node group (only meaningful with enable_eks)."
  type        = bool
  default     = true
}

variable "github_repo" {
  description = "GitHub repo (owner/name, e.g. nirl10/travel_log) allowed to deploy via OIDC. Empty disables the CD role."
  type        = string
  default     = ""
}

variable "route53_domain" {
  description = "Domain for the practice Route 53 zone. Records resolve publicly only once this domain is actually registered/delegated."
  type        = string
  default     = "travellog-nirl10.click"
}

# --- Optional RDS (level 17 — default OFF; cost guardrail) ---

variable "enable_rds" {
  description = "Enable the optional RDS module. Keep false by default — see .claude/levels/level-17-rds-optional.md. Requires enable_eks (RDS has nothing to talk to otherwise)."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_rds || var.enable_eks
    error_message = "enable_rds requires enable_eks=true — RDS has no consumer without the EKS cluster."
  }
}

variable "rds_instance_class" {
  type    = string
  default = "db.t3.small"
}
