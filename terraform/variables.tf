# =============================================================================
# INPUT VARIABLES — AWS Academy Compatible
# =============================================================================
# These variables make our Terraform configuration reusable and configurable.
# Values can be overridden via terraform.tfvars, CLI flags, or environment vars.
# =============================================================================

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (lab, dev, staging, production)"
  type        = string
  default     = "lab"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "taskflow"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "container_port" {
  description = "Port the container application listens on"
  type        = number
  default     = 3001
}

variable "task_cpu" {
  description = "CPU units for ECS task (256 = 0.25 vCPU)"
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Memory (MB) for ECS task"
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 1
}

variable "health_check_path" {
  description = "Path for ALB health check"
  type        = string
  default     = "/api/health"
}
