resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_alb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = var.active_target == "prod" ? aws_lb_target_group.prod.arn : aws_lb_target_group.dev.arn
  }
}