# prod ASG - always attached to prod target group; desired capacity based on active_target
resource "aws_autoscaling_group" "prod" {
  name                      = "prod-asg"
  max_size                  = 4
  min_size                  = 0
  desired_capacity          = var.active_target == "prod" ? 1 : 0
  vpc_zone_identifier       = [aws_subnet.public1.id, aws_subnet.public2.id]
  target_group_arns         = [aws_lb_target_group.prod.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 600

  launch_template {
    id      = aws_launch_template.prod.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "prod-app-instance"
    propagate_at_launch = true
  }
}

# dev ASG - always attached to dev target group; desired capacity based on active_target
resource "aws_autoscaling_group" "dev" {
  name                      = "dev-asg"
  max_size                  = 4
  min_size                  = 0
  desired_capacity          = var.active_target == "dev" ? 1 : 0
  vpc_zone_identifier       = [aws_subnet.public1.id, aws_subnet.public2.id]
  target_group_arns         = [aws_lb_target_group.dev.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 600

  launch_template {
    id      = aws_launch_template.dev.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "dev-app-instance"
    propagate_at_launch = true
  }
}
