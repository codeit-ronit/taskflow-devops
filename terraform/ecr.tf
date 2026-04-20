# =============================================================================
# AWS ECR (Elastic Container Registry)
# =============================================================================
# ECR is AWS's private Docker image registry.
# Our pipeline builds images and pushes them here.
# ECS then pulls images from here to run containers.
#
# force_delete: allows destroying repo even if images exist (lab cleanup)
# scan_on_push: checks images for known vulnerabilities
# Lifecycle policy: keeps only last 5 images to save storage
# =============================================================================

resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-server"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-ecr"
    Environment = var.environment
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}
