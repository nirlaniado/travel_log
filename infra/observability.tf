# Level 30: kube-prometheus-stack + Loki, pinned to the tainted obs node
# group. Config mirrors what was validated live on the local k3d cluster
# (same nodeSelector/toleration shape, resource requests sized for t3.small).

locals {
  obs_on = var.enable_eks && var.enable_observability ? 1 : 0

  obs_node_pin = {
    nodeSelector = { role = "obs" }
    tolerations = [{
      key      = "role"
      operator = "Equal"
      value    = "obs"
      effect   = "NoSchedule"
    }]
  }
}

# EKS's built-in "gp2" StorageClass exists but isn't marked default, so any
# PVC that doesn't set storageClassName explicitly (Loki's included) sits
# Pending forever ("unbound immediate PersistentVolumeClaims"). Managed here
# via Terraform rather than a manual `kubectl annotate`, so it survives a
# destroy/apply cycle like everything else.
resource "kubernetes_annotations" "gp2_default" {
  count       = local.eks_on
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = "gp2"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "true"
  }
  force = true

  depends_on = [aws_eks_node_group.this]
}

resource "helm_release" "kube_prometheus_stack" {
  count            = local.obs_on
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  wait             = true
  timeout          = 900

  values = [yamlencode({
    alertmanager = { enabled = false }
    prometheus = {
      prometheusSpec = merge(local.obs_node_pin, {
        retention = "2d"
        resources = {
          requests = { cpu = "100m", memory = "384Mi" }
          limits   = { cpu = "500m", memory = "768Mi" }
        }
        # Pick up ServiceMonitors from any namespace/release (the travellog
        # chart's backend ServiceMonitor comes with level 21's /metrics work).
        serviceMonitorSelectorNilUsesHelmValues = false
      })
      # NOTE: Prometheus/Grafana are intentionally NOT exposed via ingress —
      # access with kubectl port-forward. Keep it that way until auth is
      # thought through.
    }
    grafana = merge(local.obs_node_pin, {
      adminPassword = var.grafana_admin_password
      resources = {
        requests = { cpu = "50m", memory = "192Mi" }
        limits   = { cpu = "200m", memory = "384Mi" }
      }
    })
    kube-state-metrics = local.obs_node_pin
    prometheusOperator = merge(local.obs_node_pin, {
      admissionWebhooks = {
        patch = local.obs_node_pin
      }
    })
  })]

  # Also depends on the ALB controller: its mutating webhook intercepts ALL
  # Service creation cluster-wide (not just LoadBalancer-type), so any
  # helm_release creating Services can hit "no endpoints available for
  # service aws-load-balancer-webhook-service" if it races ahead of the
  # controller's pods being Ready — hit this for real on 2026-07-15.
  depends_on = [aws_eks_node_group.this, aws_eks_addon.coredns, helm_release.lb_controller]
}

resource "helm_release" "loki" {
  count            = local.obs_on
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki"
  namespace        = "monitoring"
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [yamlencode({
    deploymentMode = "SingleBinary"
    singleBinary = merge(local.obs_node_pin, {
      replicas = 1
      resources = {
        requests = { cpu = "50m", memory = "256Mi" }
        limits   = { cpu = "200m", memory = "512Mi" }
      }
      persistence = { enabled = true, size = "10Gi", storageClass = "gp2" }
    })
    loki = {
      auth_enabled = false
      commonConfig = { replication_factor = 1 }
      schemaConfig = {
        configs = [{
          from         = "2024-01-01"
          store        = "tsdb"
          object_store = "filesystem"
          schema       = "v13"
          index        = { prefix = "loki_index_", period = "24h" }
        }]
      }
      storage = {
        type = "filesystem"
        bucketNames = {
          chunks = "chunks"
          ruler  = "ruler"
          admin  = "admin"
        }
      }
    }
    read    = { replicas = 0 }
    write   = { replicas = 0 }
    backend = { replicas = 0 }
    gateway = { enabled = false }
    test    = { enabled = false }
    # These are separate memcached-backed StatefulSets with their own PVCs —
    # extra failure surface not worth it for a small practice instance.
    resultsCache = { enabled = false }
    chunksCache  = { enabled = false }
    monitoring = {
      serviceMonitor = { enabled = false }
      selfMonitoring = { enabled = false }
      lokiCanary     = { enabled = false }
    }
  })]

  # Same ALB-webhook race as kube_prometheus_stack above.
  depends_on = [aws_eks_node_group.this, aws_eks_addon.ebs_csi, helm_release.lb_controller]
}
