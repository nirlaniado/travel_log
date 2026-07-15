# In-cluster deployment via Terraform (level 28): the travellog chart behind
# an ALB (created by the AWS Load Balancer Controller from the Ingress — see
# alb.tf for the controller, the TF-managed security groups, ACM cert, and
# Route 53). Single apply in, single destroy out.
#
# Host strategy without a registered domain: the Ingress carries NO host rule
# (catch-all), so the app answers on the ALB's own hostname, the nip.io alias
# of its IP (the working URL — see eks_app_url output), and the Route 53 name
# once the domain is ever registered. The TLS cert's CN is the stable Route 53
# FQDN; browsers warn regardless (self-signed) until a real domain + ACM cert.

locals {
  app_fqdn = "app.${var.route53_domain}"
}

provider "kubernetes" {
  host                   = try(aws_eks_cluster.this[0].endpoint, null)
  cluster_ca_certificate = try(base64decode(aws_eks_cluster.this[0].certificate_authority[0].data), null)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.eks_cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes {
    host                   = try(aws_eks_cluster.this[0].endpoint, null)
    cluster_ca_certificate = try(base64decode(aws_eks_cluster.this[0].certificate_authority[0].data), null)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", local.eks_cluster_name, "--region", var.aws_region]
    }
  }
}

# --- Self-signed TLS keypair (imported into ACM in alb.tf) ---

resource "tls_private_key" "app" {
  count     = local.eks_on
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "app" {
  count           = local.eks_on
  private_key_pem = tls_private_key.app[0].private_key_pem

  subject {
    common_name = local.app_fqdn
  }

  dns_names             = [local.app_fqdn]
  validity_period_hours = 24 * 365
  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]
}

# --- The app ---

resource "helm_release" "travellog" {
  count     = local.eks_on
  name      = "travellog"
  chart     = "${path.module}/../charts/travellog"
  namespace = "default"
  wait      = true
  timeout   = 600

  values = [
    file("${path.module}/../charts/travellog/values.yaml"),
    file("${path.module}/../charts/travellog/values-eks.yaml"),
    yamlencode({
      image = {
        backend = {
          repository = aws_ecr_repository.backend.repository_url
          tag        = var.backend_image_tag
        }
        frontend = {
          repository = aws_ecr_repository.frontend.repository_url
          tag        = var.frontend_image_tag
        }
      }
      backend = {
        env = {
          # Same-origin through the ALB (frontend built with VITE_API_URL=/api)
          # means CORS never fires for the app itself; this stays for direct
          # API access via the Route 53 name.
          corsOrigins = "https://${local.app_fqdn}"
        }
      }
      ingress = {
        annotations = {
          "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
          "alb.ingress.kubernetes.io/target-type"     = "ip"
          "alb.ingress.kubernetes.io/listen-ports"    = jsonencode([{ HTTP = 80 }, { HTTPS = 443 }])
          "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
          "alb.ingress.kubernetes.io/certificate-arn" = aws_acm_certificate.app[0].arn
          # TF-managed SG on the ALB; controller adds no rules of its own here
          "alb.ingress.kubernetes.io/security-groups"  = aws_security_group.alb[0].id
          "alb.ingress.kubernetes.io/healthcheck-path" = "/health"
        }
      }
    }),
  ]

  set_sensitive {
    name  = "secrets.mysqlUser"
    value = var.mysql_user
  }

  set_sensitive {
    name  = "secrets.mysqlPassword"
    value = var.mysql_password
  }

  set_sensitive {
    name  = "secrets.mysqlRootPassword"
    value = var.mysql_root_password
  }

  depends_on = [
    aws_eks_addon.ebs_csi,
    helm_release.lb_controller,
    aws_vpc_security_group_ingress_rule.nodes_from_alb,
  ]
}

# ALB hostname (assigned by the controller after the Ingress exists). If the
# hostname or its DNS isn't ready on a fresh apply, re-run terraform apply.
data "kubernetes_ingress_v1" "travellog" {
  count = local.eks_on

  metadata {
    name      = "travellog"
    namespace = "default"
  }

  depends_on = [helm_release.travellog]
}

data "dns_a_record_set" "ingress_lb" {
  count = local.eks_on
  host  = data.kubernetes_ingress_v1.travellog[0].status[0].load_balancer[0].ingress[0].hostname
}

locals {
  eks_app_host = var.enable_eks ? "travellog.${try(data.dns_a_record_set.ingress_lb[0].addrs[0], "pending")}.nip.io" : null
}
