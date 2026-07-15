#!/usr/bin/env bash
# Two-phase EKS teardown.
#
# Why two phases: infra/helm.tf configures the kubernetes/helm providers
# from the EKS cluster's own attributes (endpoint, CA cert, an
# `aws eks get-token` exec call). A plain `terraform destroy` can fail
# partway through with "Kubernetes cluster unreachable" once Terraform
# starts removing cluster-dependent resources out of order — hit this for
# real on 2026-07-14. Fix: destroy the cluster-dependent resources first,
# explicitly, while the cluster can still authenticate them, then destroy
# everything else.
#
# Usage:
#   scripts/terraform_destroy_eks.sh          # dry run — plans both phases, applies nothing
#   scripts/terraform_destroy_eks.sh --yes    # actually runs both phases
set -euo pipefail

INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../infra" && pwd)"
cd "$INFRA_DIR"

PHASE1_PLAN="${TMPDIR:-/tmp}/travellog-destroy-phase1.tfplan"
PHASE2_PLAN="${TMPDIR:-/tmp}/travellog-destroy-phase2.tfplan"

CLUSTER_DEPENDENT_TARGETS=(
  -target=helm_release.travellog
  -target=helm_release.loki
  -target=helm_release.kube_prometheus_stack
  -target=helm_release.lb_controller
  -target=kubernetes_annotations.gp2_default
)

APPLY=false
if [[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]]; then
  APPLY=true
fi

echo "=== Phase 1 plan: cluster-dependent resources (helm releases, storage class annotation) ==="
terraform plan -destroy -var enable_eks=true "${CLUSTER_DEPENDENT_TARGETS[@]}" -out="$PHASE1_PLAN"

if [[ "$APPLY" == false ]]; then
  echo
  echo "Dry run only (nothing was destroyed). Re-run with --yes to apply phase 1, then phase 2."
  exit 0
fi

echo
echo "=== Applying phase 1 ==="
terraform apply "$PHASE1_PLAN"

echo
echo "=== Phase 2 plan: everything else (EKS cluster, node groups, VPC, IAM, ECR, ACM, Route 53) ==="
terraform plan -destroy -var enable_eks=true -out="$PHASE2_PLAN"

echo
echo "=== Applying phase 2 ==="
terraform apply "$PHASE2_PLAN"

echo
echo "=== Verifying ==="
remaining="$(terraform state list 2>&1 || true)"
if [[ -z "$remaining" ]]; then
  echo "terraform state is empty — teardown complete."
else
  echo "WARNING: terraform state is not empty, investigate:"
  echo "$remaining"
  exit 1
fi

echo
echo "Independent AWS check (no terraform involved):"
region="${AWS_REGION:-eu-north-1}"
echo "  EKS clusters:      $(aws eks list-clusters --region "$region" --query 'clusters' --output text 2>&1)"
echo "  Load balancers:    $(aws elbv2 describe-load-balancers --region "$region" --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-default-travello')].LoadBalancerName" --output text 2>&1)"
echo "  ECR backend repo:  $(aws ecr describe-repositories --region "$region" --repository-names travellog/backend --query 'repositories[0].repositoryName' --output text 2>&1 || echo 'gone (expected)')"
echo
echo "Still around on purpose (outside this terraform state, cheap to keep):"
echo "  S3 bucket:         s3-travellog-nirl10 (MySQL backups)"
echo "  DynamoDB table:    travellog-tf-lock (terraform state lock, on-demand billing)"
