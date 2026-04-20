# =============================================================================
# TERRAFORM OUTPUTS
# =============================================================================
# These values are printed after terraform apply and can be referenced
# by other systems (like our GitHub Actions workflow).
# =============================================================================

output "alb_dns_url" {
  description = "Application Load Balancer DNS URL (access your app here)"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecr_repository_url" {
  description = "ECR repository URL for Docker push"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.app.name
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "s3_bucket_name" {
  description = "S3 application storage bucket name"
  value       = aws_s3_bucket.app_storage.id
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for ECS container logs"
  value       = aws_cloudwatch_log_group.ecs.name
}

output "lab_role_arn" {
  description = "AWS Academy LabRole ARN (pre-existing, not created by Terraform)"
  value       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
}
