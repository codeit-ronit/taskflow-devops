# =============================================================================
# CLOUDWATCH LOG GROUP
# =============================================================================
# ECS Fargate sends container stdout/stderr to CloudWatch Logs.
# This lets you view application logs without SSH-ing into anything.
#
# Retention: 7 days (lab environment, saves cost)
# =============================================================================

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-ecs-logs"
    Environment = var.environment
  }
}
