output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = module.eks.cluster_iam_role_name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_version" {
  description = "The Kubernetes version for the cluster"
  value       = module.eks.cluster_version
}

output "app_node_group_autoscaling_group_names" {
  description = "The autoscaling group names for the app node group"
  value       = module.eks.eks_managed_node_groups_autoscaling_group_names
}

output "aurora_cluster_endpoint" {
  description = "The cluster endpoint for Aurora PostgreSQL"
  value       = module.aurora_postgresql_serverless_v2.cluster_endpoint
}

output "aurora_cluster_reader_endpoint" {
  description = "The cluster reader endpoint for Aurora PostgreSQL"
  value       = module.aurora_postgresql_serverless_v2.cluster_reader_endpoint
}

output "aurora_cluster_identifier" {
  description = "The cluster identifier for Aurora PostgreSQL"
  value       = module.aurora_postgresql_serverless_v2.cluster_id
}

output "aurora_cluster_resource_id" {
  description = "The Resource ID of the Aurora cluster"
  value       = module.aurora_postgresql_serverless_v2.cluster_resource_id
} 