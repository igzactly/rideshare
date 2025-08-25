variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "rideshare"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["eu-west-2a", "eu-west-2b"]
}

variable "app_image" {
  description = "Docker image for the application"
  type        = string
  default     = "rideshare-api:latest"
}

variable "app_port" {
  description = "Port exposed by the application"
  type        = number
  default     = 8000
}

variable "app_count" {
  description = "Number of application instances"
  type        = number
  default     = 2
}

variable "mongodb_atlas_public_key" {
  description = "MongoDB Atlas public key"
  type        = string
  sensitive   = true
}

variable "mongodb_atlas_private_key" {
  description = "MongoDB Atlas private key"
  type        = string
  sensitive   = true
}

variable "mongodb_atlas_project_id" {
  description = "MongoDB Atlas project ID"
  type        = string
}

# MongoDB Atlas module pass-through variables
variable "mongodb_provider_region" {
  description = "AWS region name used by MongoDB Atlas (e.g. EU_WEST_1)"
  type        = string
  default     = "EU_WEST_1"
}

variable "mongodb_instance_size" {
  description = "MongoDB Atlas instance size (e.g. M0, M10)"
  type        = string
  default     = "M0"
}

variable "mongodb_database_password" {
  description = "Password for the MongoDB Atlas database user"
  type        = string
  sensitive   = true
}

variable "mongodb_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access MongoDB Atlas (e.g. 0.0.0.0/0)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "mapbox_access_token" {
  description = "Mapbox access token for mapping services"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT secret for authentication"
  type        = string
  sensitive   = true
}

variable "kafka_bootstrap_servers" {
  description = "Kafka bootstrap servers"
  type        = string
  default     = "localhost:9092"
}
