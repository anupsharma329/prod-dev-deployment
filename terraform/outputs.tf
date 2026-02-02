output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_alb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the ALB (for Route53 alias if needed)"
  value       = aws_alb.main.zone_id
}

output "app_url" {
  description = "URL to access the application (use after DNS propagates or add to /etc/hosts)"
  value       = "http://${aws_alb.main.dns_name}"
}

output "active_target" {
  description = "Currently active target group (prod or dev)"
  value       = var.active_target
}
