# ALB in front of the app (replaces ingress-nginx/NLB on EKS) + Route 53.
#
# - The ALB itself is created by the AWS Load Balancer Controller from the
#   travellog Ingress (class alb), but its SECURITY GROUP is defined here in
#   Terraform and passed via annotation — that's the explicit "ALB security
#   rules" layer. Node access is likewise a TF-managed rule: only the ALB SG
#   may reach the cluster SG.
# - TLS terminates at the ALB with the self-signed cert imported into ACM
#   (free). With a registered domain later: swap for a real ACM-issued cert.
# - Route 53 zone/records are real IaC but resolve publicly only once the
#   domain is registered/delegated — until then the working URL is the
#   nip.io output. Zone lives/dies with the cluster (enable_eks) so the
#   default plan stays $0.

# --- ALB security group (the "front door" rules) ---

resource "aws_security_group" "alb" {
  count       = local.eks_on
  name        = "travellog-alb"
  description = "ALB: HTTP/HTTPS from the internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP (redirected to HTTPS at the listener)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "travellog-alb"
  }
}

# Nodes accept traffic ONLY from the ALB (pod target ports, target-type ip).
resource "aws_vpc_security_group_ingress_rule" "nodes_from_alb" {
  count                        = local.eks_on
  security_group_id            = aws_eks_cluster.this[0].vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.alb[0].id
  ip_protocol                  = "tcp"
  from_port                    = 0
  to_port                      = 65535
  description                  = "ALB to pod target ports"
}

# --- IRSA for the AWS Load Balancer Controller ---

data "aws_iam_policy_document" "lb_controller_assume" {
  count = local.eks_on

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks[0].arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.this[0].identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "lb_controller" {
  count              = local.eks_on
  name               = "travellog-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_assume[0].json
}

resource "aws_iam_role_policy" "lb_controller" {
  count  = local.eks_on
  name   = "alb-controller"
  role   = aws_iam_role.lb_controller[0].id
  policy = file("${path.module}/policies/aws-load-balancer-controller.json")
}

resource "helm_release" "lb_controller" {
  count      = local.eks_on
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  wait       = true
  timeout    = 600

  values = [yamlencode({
    clusterName = aws_eks_cluster.this[0].name
    region      = var.aws_region
    vpcId       = aws_vpc.main.id
    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller"
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.lb_controller[0].arn
      }
    }
    nodeSelector = { role = "app" }
  })]

  depends_on = [
    aws_eks_node_group.this,
    aws_eks_addon.coredns,
    aws_iam_role_policy.lb_controller,
  ]
}

# --- TLS: self-signed cert imported into ACM (free; browser-warns) ---

resource "aws_acm_certificate" "app" {
  count            = local.eks_on
  certificate_body = tls_self_signed_cert.app[0].cert_pem
  private_key      = tls_private_key.app[0].private_key_pem

  tags = {
    Name = "travellog-selfsigned"
  }
}

# --- Route 53 (practice zone — resolves once the domain is registered) ---

resource "aws_route53_zone" "main" {
  count   = local.eks_on
  name    = var.route53_domain
  comment = "travel_log practice zone — register/delegate ${var.route53_domain} to make it live"
}

data "aws_lb_hosted_zone_id" "alb" {}

resource "aws_route53_record" "app" {
  count   = local.eks_on
  zone_id = aws_route53_zone.main[0].zone_id
  name    = local.app_fqdn
  type    = "A"

  alias {
    name                   = data.kubernetes_ingress_v1.travellog[0].status[0].load_balancer[0].ingress[0].hostname
    zone_id                = data.aws_lb_hosted_zone_id.alb.id
    evaluate_target_health = false
  }
}
