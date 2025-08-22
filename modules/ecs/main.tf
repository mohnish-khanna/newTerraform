# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "wisemint-cluster-${var.environment}"
  
  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      
      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs_exec.name
      }
    }
  }
  
  tags = merge(var.tags, {
    Name = "wisemint-cluster-${var.environment}"
  })
}

# CloudWatch Log Group for ECS Exec
resource "aws_cloudwatch_log_group" "ecs_exec" {
  name              = "/aws/ecs/exec/wisemint-${var.environment}"
  retention_in_days = 7
  
  tags = var.tags
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "wisemint-ecs-tasks-${var.environment}"
  vpc_id      = var.vpc_id
  
  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Access from VPC"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }
  
  tags = merge(var.tags, {
    Name = "wisemint-ecs-tasks-sg-${var.environment}"
  })
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution" {
  name = "wisemint-ecs-task-execution-${var.environment}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task" {
  name = "wisemint-ecs-task-${var.environment}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

# Attach policies to ECS Task Execution Role
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Custom policy for ECS Task Execution Role (for Parameter Store access)
resource "aws_iam_role_policy" "ecs_task_execution_custom" {
  name = "wisemint-ecs-task-execution-custom-${var.environment}"
  role = aws_iam_role.ecs_task_execution.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/wisemint/${var.environment}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}

# Custom policy for ECS Task Role
resource "aws_iam_role_policy" "ecs_task_custom" {
  name = "wisemint-ecs-task-custom-${var.environment}"
  role = aws_iam_role.ecs_task.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      }
    ]
  })
}

# Parameter Store values
resource "aws_ssm_parameter" "db_password" {
  name  = "/wisemint/${var.environment}/db/password"
  type  = "SecureString"
  value = var.db_password
  
  tags = var.tags
}

resource "aws_ssm_parameter" "plaid_client_secret" {
  name  = "/wisemint/${var.environment}/plaid/client_secret"
  type  = "SecureString"
  value = var.plaid_client_secret
  
  tags = var.tags
}

resource "aws_ssm_parameter" "alpha_vantage_api_key" {
  name  = "/wisemint/${var.environment}/alphavantage/api_key"
  type  = "SecureString"
  value = var.alpha_vantage_api_key
  
  tags = var.tags
}

resource "aws_ssm_parameter" "ses_smtp_password" {
  name  = "/wisemint/${var.environment}/ses/smtp_password"
  type  = "SecureString"
  value = var.ses_smtp_password
  
  tags = var.tags
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "wisemint-app-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn           = aws_iam_role.ecs_task.arn
  
  container_definitions = jsonencode([
    {
      name  = "wisemint-app"
      image = "${var.ecr_repository_url}:latest"
      
      portMappings = [
        {
          containerPort = var.app_port
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = var.environment
        },
        {
          name  = "MYSQL_JDBC_URL"
          value = "jdbc:mysql://${var.db_host}/${var.db_name}"
        },
        {
          name  = "MYSQL_USER"
          value = var.db_username
        },
        {
          name  = "PLAID_CLIENT_ID"
          value = var.plaid_client_id
        },
        {
          name  = "PLAID_CLIENT_NAME"
          value = var.plaid_client_name
        },
        {
          name  = "PLAID_BASE_URL"
          value = "https://production.plaid.com"
        },
        {
          name  = "PLAID_WEBHOOK_URL"
          value = "https://${var.domain_name}/api/v1/webhooks/plaid"
        },
        {
          name  = "PLAID_REDIRECT_URL"
          value = "https://${var.domain_name}/callback"
        },
        {
          name  = "ALPHA_VANTAGE_BASE_URL"
          value = "https://www.alphavantage.co"
        },
        {
          name  = "SES_SMTP_HOST"
          value = "email-smtp.${data.aws_region.current.name}.amazonaws.com"
        },
        {
          name  = "SES_SMTP_PORT"
          value = "587"
        },
        {
          name  = "SES_SMTP_USERNAME"
          value = var.ses_smtp_username
        },
        {
          name  = "EMAIL_FROM"
          value = var.email_from
        },
        {
          name  = "EMAIL_SUBJECT"
          value = "WiseMint OTP"
        },
        {
          name  = "EMAIL_TEMPLATE"
          value = "email_verification.ftl"
        }
      ]
      
      secrets = [
        {
          name      = "MYSQL_PASSWORD"
          valueFrom = aws_ssm_parameter.db_password.arn
        },
        {
          name      = "PLAID_CLIENT_SECRET"
          valueFrom = aws_ssm_parameter.plaid_client_secret.arn
        },
        {
          name      = "ALPHA_VANTAGE_API_KEY"
          valueFrom = aws_ssm_parameter.alpha_vantage_api_key.arn
        },
        {
          name      = "SES_SMTP_PASSWORD"
          valueFrom = aws_ssm_parameter.ses_smtp_password.arn
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/wisemint-portfolio-analysis-${var.environment}"
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:${var.app_port}/actuator/health || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])
  
  tags = merge(var.tags, {
    Name = "wisemint-app-${var.environment}"
  })
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "wisemint-app-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  
  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = var.private_subnet_ids
    assign_public_ip = false
  }
  
  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "wisemint-app"
    container_port   = var.app_port
  }
  
  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
  }
  
  depends_on = [var.target_group_arn]
  
  tags = merge(var.tags, {
    Name = "wisemint-app-${var.environment}"
  })
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = var.environment == "prod" ? 10 : 4
  min_capacity       = var.desired_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy - CPU
resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  name               = "wisemint-cpu-scaling-${var.environment}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace
  
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Auto Scaling Policy - Memory
resource "aws_appautoscaling_policy" "ecs_policy_memory" {
  name               = "wisemint-memory-scaling-${var.environment}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace
  
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80.0
  }
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}