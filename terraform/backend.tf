# =============================================================================
# TERRAFORM REMOTE BACKEND CONFIGURATION — AWS Academy Compatible
# =============================================================================
# Stores terraform.tfstate in S3 so the pipeline remembers what was created.
# use_lockfile = true replaces the old dynamodb_table-based locking.
#
# PREREQUISITE: Create this S3 bucket BEFORE running terraform init.
# See instructions below or in PIPELINE_GUIDE.md.
# =============================================================================

terraform {
  backend "s3" {
    bucket       = "taskflow-terraform-state-ronit"
    key          = "ecs-fargate/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
