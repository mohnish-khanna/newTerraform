# Development Environment Configuration

# Environment Configuration
environment = "dev"
aws_region  = "us-east-1"

# Network Configuration
vpc_cidr = "10.0.0.0/16"

# Database Configuration
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
db_name             = "wisemint_db"
db_username         = "wisemint_user"
# db_password will be set via environment variable or prompted

# ECS Configuration
ecs_cpu           = 512
ecs_memory        = 1024
ecs_desired_count = 1
app_port          = 8388

# Domain and SSL Configuration (update with your actual domain)
domain_name = "dev-api.yourdomain.com"
# ssl_certificate_arn will be set after creating certificate

# External Service Configuration (update with your actual values)
# plaid_client_id will be set via environment variable
# plaid_client_secret will be set via environment variable
plaid_client_name = "WiseMint Portfolio Analysis Dev"
# alpha_vantage_api_key will be set via environment variable

# Email Configuration
email_from = "noreply@yourdomain.com"