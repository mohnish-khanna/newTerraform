terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    # Configure after creating S3 bucket
    # bucket = "wisemint-terraform-state"
    # key    = "wisemint-portfolio-analysis/terraform.tfstate"
    # region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "WiseMint Portfolio Analysis"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  environment         = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = data.aws_availability_zones.available.names
  
  tags = local.common_tags
}

# RDS Module
module "rds" {
  source = "./modules/rds"
  
  environment           = var.environment
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  db_instance_class    = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  db_name             = var.db_name
  db_username         = var.db_username
  db_password         = var.db_password
  
  tags = local.common_tags
}

# ECR Repository
resource "aws_ecr_repository" "wisemint_app" {
  name                 = "wisemint-portfolio-analysis"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  lifecycle_policy {
    policy = jsonencode({
      rules = [
        {
          rulePriority = 1
          description  = "Keep last 10 images"
          selection = {
            tagStatus     = "tagged"
            tagPrefixList = ["v"]
            countType     = "imageCountMoreThan"
            countNumber   = 10
          }
          action = {
            type = "expire"
          }
        }
      ]
    })
  }
  
  tags = local.common_tags
}

# Application Load Balancer Module
module "alb" {
  source = "./modules/alb"
  
  environment        = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  certificate_arn   = var.ssl_certificate_arn
  domain_name       = var.domain_name
  
  tags = local.common_tags
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"
  
  environment           = var.environment
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  target_group_arn     = module.alb.target_group_arn
  ecr_repository_url   = aws_ecr_repository.wisemint_app.repository_url
  
  # Database configuration
  db_host     = module.rds.db_endpoint
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
  
  # Application configuration
  app_port           = var.app_port
  cpu               = var.ecs_cpu
  memory            = var.ecs_memory
  desired_count     = var.ecs_desired_count
  
  # External service configuration
  plaid_client_id       = var.plaid_client_id
  plaid_client_secret   = var.plaid_client_secret
  plaid_client_name     = var.plaid_client_name
  alpha_vantage_api_key = var.alpha_vantage_api_key
  domain_name           = var.domain_name
  
  # Email configuration
  ses_smtp_username = module.ses.smtp_username
  ses_smtp_password = module.ses.smtp_password
  email_from        = var.email_from
  
  tags = local.common_tags
}

# SES Module
module "ses" {
  source = "./modules/ses"
  
  domain_name = var.domain_name
  email_from  = var.email_from
  
  tags = local.common_tags
}

# Route53 Module
module "route53" {
  source = "./modules/route53"
  
  domain_name     = var.domain_name
  alb_dns_name    = module.alb.alb_dns_name
  alb_zone_id     = module.alb.alb_zone_id
  
  tags = local.common_tags
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "wisemint_app" {
  name              = "/ecs/wisemint-portfolio-analysis-${var.environment}"
  retention_in_days = 30
  
  tags = local.common_tags
}

# Local values
locals {
  common_tags = {
    Project     = "WiseMint Portfolio Analysis"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}