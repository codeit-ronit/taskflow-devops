# =============================================================================
# TERRAFORM VARIABLE VALUES — AWS Academy Lab
# =============================================================================
# Override default values here. These are the values used for deployment.
# AWS Academy: No IAM creation, uses LabRole automatically.
# =============================================================================

aws_region        = "us-east-1"
environment       = "lab"
project_name      = "taskflow"
vpc_cidr          = "10.0.0.0/16"
container_port    = 3001
task_cpu          = "512"
task_memory       = "1024"
desired_count     = 1
health_check_path = "/api/health"
