terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 1.0"
    }
  }
  
  backend "s3" {
    bucket = "rideshare-terraform-state"
    key    = "rideshare/terraform.tfstate"
    region = "eu-west-2"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "RideShare"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "Ignatius Gonsalves"
    }
  }
}

provider "mongodbatlas" {
  public_key  = var.mongodb_atlas_public_key
  private_key = var.mongodb_atlas_private_key
}

# VPC and Networking
module "vpc" {
  source = "./modules/vpc"
  
  environment = var.environment
  vpc_cidr   = var.vpc_cidr
  azs        = var.availability_zones
}

# ECS Cluster and Services
module "ecs" {
  source = "./modules/ecs"
  
  environment           = var.environment
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  public_subnet_ids    = module.vpc.public_subnet_ids
  app_image            = var.app_image
  app_port             = var.app_port
  app_count            = var.app_count
  depends_on           = [module.vpc]
}

# MongoDB Atlas Cluster
module "mongodb" {
  source = "./modules/mongodb"
  
  environment = var.environment
  project_id = var.mongodb_atlas_project_id
  
  # Pass-through configuration
  provider_region     = var.mongodb_provider_region
  instance_size       = var.mongodb_instance_size
  database_password   = var.mongodb_database_password
  allowed_cidr_blocks = var.mongodb_allowed_cidr_blocks
}

# Application Load Balancer
module "alb" {
  source = "./modules/alb"
  
  environment       = var.environment
  vpc_id           = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  depends_on       = [module.ecs]
}

# CloudWatch Logs
module "cloudwatch" {
  source = "./modules/cloudwatch"
  
  environment = var.environment
  app_name   = var.app_name
}

# Outputs
output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = module.alb.alb_dns_name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "mongodb_connection_string" {
  description = "MongoDB Atlas connection string"
  value       = module.mongodb.connection_string
  sensitive   = true
}
