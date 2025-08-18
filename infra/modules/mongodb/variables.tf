variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_id" {
  description = "MongoDB Atlas project ID"
  type        = string
}

variable "provider_region" {
  description = "AWS region for MongoDB Atlas cluster"
  type        = string
  default     = "EU_WEST_1"
}

variable "instance_size" {
  description = "MongoDB Atlas instance size"
  type        = string
  default     = "M0"  # Free tier
}

variable "database_password" {
  description = "Password for the database user"
  type        = string
  sensitive   = true
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access MongoDB Atlas"
  type        = string
  default     = "0.0.0.0/0"  # Allow all for development
}
