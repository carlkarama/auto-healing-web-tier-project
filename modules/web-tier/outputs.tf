output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.web.dns_name
}

output "target_group_arn" {
  description = "ARN of the web target group"
  value       = aws_lb_target_group.web.arn
}

output "web_security_group_id" {
  description = "ID of the security group assigned to web instances"
  value       = aws_security_group.web.id
}