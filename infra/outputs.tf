output "ecr_backend_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_repository_url" {
  value = aws_ecr_repository.frontend.repository_url
}

output "rds_endpoint" {
  description = "null unless enable_rds=true"
  value       = var.enable_rds ? aws_db_instance.mysql[0].endpoint : null
}

output "eks_cluster_name" {
  description = "null unless enable_eks=true. Kubeconfig: aws eks update-kubeconfig --name <this> --region eu-north-1"
  value       = var.enable_eks ? aws_eks_cluster.this[0].name : null
}

output "eks_app_url" {
  description = "Live app on EKS via the ALB's nip.io alias (self-signed TLS — browsers will warn). Null unless enable_eks=true."
  value       = var.enable_eks ? "https://${local.eks_app_host}" : null
}

output "app_fqdn" {
  description = "Route 53 name for the app — resolves publicly only once the domain is registered/delegated."
  value       = var.enable_eks ? local.app_fqdn : null
}

output "route53_name_servers" {
  description = "Delegate the domain to these NS records to make the zone live. Null unless enable_eks=true."
  value       = var.enable_eks ? aws_route53_zone.main[0].name_servers : null
}
