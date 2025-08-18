output "app_log_group_name" {
  description = "Name of the application log group"
  value       = aws_cloudwatch_log_group.app.name
}

output "alb_log_group_name" {
  description = "Name of the ALB log group"
  value       = aws_cloudwatch_log_group.alb.name
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_arn" {
  description = "ARN of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_arn
}
