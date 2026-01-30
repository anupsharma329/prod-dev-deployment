# Target groups use port 3000 to match Node.js app listen port
resource "aws_lb_target_group" "blue" {
  name     = "blue-tg"
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
    Name = "blue-tg"
  }
}

resource "aws_lb_target_group" "green" {
  name     = "green-tg"
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
    Name = "green-tg"
  }
}