# =============================================================================
# TERRAFORM PROVIDER CONFIGURATION — AWS Academy Compatible
# =============================================================================
# AWS Academy uses a pre-existing LabRole. We do NOT create any IAM resources.
# Provider version ~> 6.0 for latest features.
# =============================================================================

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Auto-fetch current AWS Account ID (used to reference LabRole ARN)
data "aws_caller_identity" "current" {}
