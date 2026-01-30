# Blue ASG - always attached to blue target group; desired capacity based on active_target
resource "aws_autoscaling_group" "blue" {
  name                      = "blue-asg"
  max_size                  = 4
  min_size                  = 1
  desired_capacity          = var.active_target == "blue" ? 1 : 0
  vpc_zone_identifier       = [aws_subnet.public1.id, aws_subnet.public2.id]
  target_group_arns         = [aws_lb_target_group.blue.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.blue.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "blue-app-instance"
    propagate_at_launch = true
  }
}

# Green ASG - always attached to green target group; desired capacity based on active_target
resource "aws_autoscaling_group" "green" {
  name                      = "green-asg"
  max_size                  = 4
  min_size                  = 0
  desired_capacity          = var.active_target == "green" ? 1 : 0
  vpc_zone_identifier       = [aws_subnet.public1.id, aws_subnet.public2.id]
  target_group_arns         = [aws_lb_target_group.green.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.green.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "green-app-instance"
    propagate_at_launch = true
  }
}
