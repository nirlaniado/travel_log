# Level 29: keyless CD — GitHub Actions assumes this role via OIDC (no
# long-lived AWS keys in repo secrets). Grants: push images to the two ECR
# repos + describe/deploy into the EKS cluster's default namespace.
# Disabled until var.github_repo is set (e.g. "nirl10/travel_log").

locals {
  gha_on     = var.github_repo != "" ? 1 : 0
  gha_eks_on = var.github_repo != "" && var.enable_eks ? 1 : 0
}

resource "aws_iam_openid_connect_provider" "github" {
  count           = local.gha_on
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # GitHub's OIDC root; AWS also pins this internally
}

data "aws_iam_policy_document" "github_assume" {
  count = local.gha_on

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github[0].arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

data "aws_iam_policy_document" "github_deploy" {
  count = local.gha_on

  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = [
      aws_ecr_repository.backend.arn,
      aws_ecr_repository.frontend.arn,
    ]
  }

  statement {
    sid       = "EksDescribe"
    actions   = ["eks:DescribeCluster"]
    resources = ["arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${local.eks_cluster_name}"]
  }
}

resource "aws_iam_role" "github_deploy" {
  count              = local.gha_on
  name               = "travellog-github-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_assume[0].json
}

resource "aws_iam_role_policy" "github_deploy" {
  count  = local.gha_on
  name   = "deploy"
  role   = aws_iam_role.github_deploy[0].id
  policy = data.aws_iam_policy_document.github_deploy[0].json
}

# Kubernetes-side access: edit rights in the default namespace only.
resource "aws_eks_access_entry" "github_deploy" {
  count         = local.gha_eks_on
  cluster_name  = aws_eks_cluster.this[0].name
  principal_arn = aws_iam_role.github_deploy[0].arn
}

resource "aws_eks_access_policy_association" "github_deploy" {
  count         = local.gha_eks_on
  cluster_name  = aws_eks_cluster.this[0].name
  principal_arn = aws_iam_role.github_deploy[0].arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = ["default"]
  }

  depends_on = [aws_eks_access_entry.github_deploy]
}

output "github_deploy_role_arn" {
  description = "Set this as the role-to-assume in .github/workflows/deploy-eks.yml. Null until github_repo is set."
  value       = var.github_repo != "" ? aws_iam_role.github_deploy[0].arn : null
}
