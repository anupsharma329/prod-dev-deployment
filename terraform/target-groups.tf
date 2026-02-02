# Target groups use port 3000 to match Node.js app listen port
resource "aws_lb_target_group" "prod" {
  name     = "prod-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200-299"
    protocol            = "HTTP"
    port                = "traffic-port"
  }
  tags = {
    Name = "prod-tg"
  }
}

resource "aws_lb_target_group" "dev" {
  name     = "dev-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200-299"
    protocol            = "HTTP"
    port                = "traffic-port"
  }
  tags = {
    Name = "dev-tg"
  }
}