variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs"
  type        = list(string)
}

variable "app_image" {
  description = "Docker image for the application"
  type        = string
}

variable "app_port" {
  description = "Port exposed by the application"
  type        = number
}

variable "app_count" {
  description = "Number of application instances"
  type        = number
}

variable "task_cpu" {
  description = "CPU units for the task"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memory for the task in MiB"
  type        = number
  default     = 512
}

variable "mongodb_uri" {
  description = "MongoDB connection URI"
  type        = string
}

variable "jwt_secret" {
  description = "JWT secret for authentication"
  type        = string
}

variable "mapbox_access_token" {
  description = "Mapbox access token"
  type        = string
}

variable "kafka_bootstrap_servers" {
  description = "Kafka bootstrap servers"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "target_group_arn" {
  description = "Target group ARN for the ALB"
  type        = string
}

variable "load_balancer_arn" {
  description = "Load balancer ARN"
  type        = string
}

variable "alb_security_group_id" {
  description = "ALB security group ID"
  type        = string
}
