resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/ecs/${var.app_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.environment}-${var.app_name}-logs"
  }
}

resource "aws_cloudwatch_log_group" "alb" {
  name              = "/aws/alb/${var.app_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.environment}-${var.app_name}-alb-logs"
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.environment}-rideshare-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", "${var.app_name}-${var.environment}-service", "ClusterName", "${var.app_name}-${var.environment}-cluster"],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "ECS Service Metrics"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "app/${var.app_name}-${var.environment}-alb", "TargetGroup", "${var.app_name}-${var.environment}-tg"],
            [".", "TargetResponseTime", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "ALB Metrics"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6

        properties = {
          query   = "SOURCE '/aws/ecs/${var.app_name}-${var.environment}'\n| fields @timestamp, @message\n| filter @message like /ERROR/\n| sort @timestamp desc\n| limit 100"
          region  = data.aws_region.current.name
          title   = "Application Error Logs"
          view    = "table"
        }
      }
    ]
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.environment}-${var.app_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ECS CPU utilization"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    ServiceName = "${var.app_name}-${var.environment}-service"
    ClusterName = "${var.app_name}-${var.environment}-cluster"
  }
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "${var.environment}-${var.app_name}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ECS memory utilization"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    ServiceName = "${var.app_name}-${var.environment}-service"
    ClusterName = "${var.app_name}-${var.environment}-cluster"
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.environment}-${var.app_name}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors ALB 5XX errors"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    LoadBalancer = "app/${var.app_name}-${var.environment}-alb"
  }
}

# Data source
data "aws_region" "current" {}
