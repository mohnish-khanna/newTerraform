# Production Environment Configuration

# Environment Configuration
environment = "prod"
aws_region  = "us-east-1"

# Network Configuration
vpc_cidr = "10.1.0.0/16"

# Database Configuration
db_instance_class    = "db.t3.small"
db_allocated_storage = 100
db_name             = "wisemint_db"
db_username         = "wisemint_user"
# db_password will be set via environment variable or prompted

# ECS Configuration
ecs_cpu           = 1024
ecs_memory        = 2048
ecs_desired_count = 3
app_port          = 8388

# Domain and SSL Configuration (update with your actual domain)
domain_name = "api.yourdomain.com"
# ssl_certificate_arn will be set after creating certificate

# External Service Configuration (update with your actual values)
# plaid_client_id will be set via environment variable
# plaid_client_secret will be set via environment variable
plaid_client_name = "WiseMint Portfolio Analysis"
# alpha_vantage_api_key will be set via environment variable

# Email Configuration
email_from = "noreply@yourdomain.com"