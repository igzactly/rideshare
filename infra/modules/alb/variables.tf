variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs"
  type        = list(string)
}

variable "app_port" {
  description = "Port exposed by the application"
  type        = number
  default     = 8000
}

variable "certificate_arn" {
  description = "SSL certificate ARN for HTTPS"
  type        = string
  default     = ""
}

variable "create_route53_record" {
  description = "Whether to create a Route53 record"
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = ""
}
