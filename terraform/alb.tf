# =============================================================================
# APPLICATION LOAD BALANCER (ALB)
# =============================================================================
# The ALB is the entry point for users accessing your application.
# It distributes incoming HTTP traffic to healthy ECS Fargate tasks.
#
# Flow: Internet → ALB (port 80) → Target Group → ECS Tasks (port 3001)
#
# The ALB provides:
# - A stable DNS URL (doesn't change when tasks restart)
# - Health checking (removes unhealthy tasks from rotation)
# - Load distribution (if you scale to multiple tasks)
# =============================================================================

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
  }
}

# Target Group: defines WHERE the ALB sends traffic and HOW it checks health
resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project_name}-target-group"
    Environment = var.environment
  }
}

# Listener: the ALB listens on port 80 and forwards to the target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
