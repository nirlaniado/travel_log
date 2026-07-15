# EKS — Phase 4 (levels 27-28). EPHEMERAL by design: apply with
#   terraform apply -var enable_ec2=false -var enable_eks=true
# verify, then flip back (-var enable_eks=false) IN THE SAME SESSION.
# Control plane ~$0.10/hr + 6 × t3.small while up.
#
# Node layout (.claude/project-spec.md): 3 managed node groups × 2 × t3.small
# — app (untainted, stateless, spread across both AZs), data and obs
# (tainted, PVC-backed) pinned to a SINGLE AZ each. EBS volumes are zonal;
# spreading a PVC-backed node group across 2 AZs means a SPOT
# replacement/rotation can land the new node in the wrong AZ, permanently
# orphaning the volume from any schedulable node ("node(s) didn't match
# PersistentVolume's node affinity") — hit this for real on 2026-07-12.
# Single-AZ per stateful group trades that tier's AZ redundancy for actually
# staying schedulable; the cluster as a whole still spans both AZs via `app`.

locals {
  eks_cluster_name = "travellog-eks"
  eks_on           = var.enable_eks ? 1 : 0

  eks_node_groups = {
    app = {
      taint      = false
      subnet_ids = aws_subnet.public[*].id
    }
    data = {
      taint      = true
      subnet_ids = [aws_subnet.public[0].id]
    }
    obs = {
      taint      = true
      subnet_ids = [aws_subnet.public[1].id]
    }
  }
}

# --- Cluster IAM ---

data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  count              = local.eks_on
  name               = "travellog-eks-cluster"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  count      = local.eks_on
  role       = aws_iam_role.eks_cluster[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# --- Cluster ---

resource "aws_eks_cluster" "this" {
  count    = local.eks_on
  name     = local.eks_cluster_name
  role_arn = aws_iam_role.eks_cluster[0].arn
  version  = var.eks_version

  vpc_config {
    subnet_ids              = aws_subnet.public[*].id
    endpoint_public_access  = true
    endpoint_private_access = false
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster]
}

# --- Node IAM (shared by all three groups) ---

data "aws_iam_policy_document" "ec2_assume_role_eks_nodes" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_nodes" {
  count              = local.eks_on
  name               = "travellog-eks-nodes"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_eks_nodes.json
}

resource "aws_iam_role_policy_attachment" "eks_nodes" {
  for_each = var.enable_eks ? toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ]) : toset([])

  role       = aws_iam_role.eks_nodes[0].name
  policy_arn = each.value
}

# --- Node groups: app / data / obs, 2 × t3.small each, both AZs ---

resource "aws_eks_node_group" "this" {
  for_each = var.enable_eks ? local.eks_node_groups : {}

  cluster_name    = aws_eks_cluster.this[0].name
  node_group_name = "travellog-${each.key}"
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids      = each.value.subnet_ids
  instance_types  = [var.instance_type]
  # ON_DEMAND, not SPOT: hit real "UnfulfillableCapacity"/"InsufficientInstanceCapacity"
  # errors for t3.small SPOT in eu-north-1 on 2026-07-15 (all 3 node groups
  # failed to launch). Still t3.small, same node counts — this only changes
  # the purchasing model. Cost delta for 6x t3.small is roughly $0.10-0.15/hr
  # total, negligible next to the control plane's own ~$0.10/hr, and worth it
  # to not be at the mercy of regional Spot availability.
  capacity_type = "ON_DEMAND"

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 2
  }

  labels = {
    role = each.key
  }

  dynamic "taint" {
    for_each = each.value.taint ? [1] : []
    content {
      key    = "role"
      value  = each.key
      effect = "NO_SCHEDULE"
    }
  }

  depends_on = [aws_iam_role_policy_attachment.eks_nodes]
}

# --- IRSA for the EBS CSI driver (MySQL PVCs on the data nodes) ---

data "tls_certificate" "eks_oidc" {
  count = local.eks_on
  url   = aws_eks_cluster.this[0].identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  count           = local.eks_on
  url             = aws_eks_cluster.this[0].identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc[0].certificates[0].sha1_fingerprint]
}

data "aws_iam_policy_document" "ebs_csi_assume" {
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
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  count              = local.eks_on
  name               = "travellog-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume[0].json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count      = local.eks_on
  role       = aws_iam_role.ebs_csi[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# --- Addons ---

resource "aws_eks_addon" "vpc_cni" {
  count        = local.eks_on
  cluster_name = aws_eks_cluster.this[0].name
  addon_name   = "vpc-cni"
}

resource "aws_eks_addon" "kube_proxy" {
  count        = local.eks_on
  cluster_name = aws_eks_cluster.this[0].name
  addon_name   = "kube-proxy"
}

resource "aws_eks_addon" "coredns" {
  count        = local.eks_on
  cluster_name = aws_eks_cluster.this[0].name
  addon_name   = "coredns"

  depends_on = [aws_eks_node_group.this]
}

resource "aws_eks_addon" "ebs_csi" {
  count                    = local.eks_on
  cluster_name             = aws_eks_cluster.this[0].name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi[0].arn

  depends_on = [aws_eks_node_group.this]
}
