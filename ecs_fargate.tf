# --- ECR Repositorio para la imagen de la API ---
resource "aws_ecr_repository" "fastapi_api" {
  name                 = "${local.prefix}-fastapi-api-repo"
  image_tag_mutability = "MUTABLE" # O "IMMUTABLE" según preferencia

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${local.prefix}-fastapi-api-repo"
  }
}

# --- ECS Cluster ---
resource "aws_ecs_cluster" "main" {
  name = "${local.prefix}-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled" # Habilita Container Insights para monitoreo mejorado
  }

  tags = {
    Name = "${local.prefix}-ecs-cluster"
  }
}

# --- Log Group para Fargate Tasks ---
resource "aws_cloudwatch_log_group" "fargate_api_logs" {
  name              = "/ecs/${local.prefix}-fastapi-api"
  retention_in_days = 30 # Ajusta según necesidad

  tags = {
    Name = "${local.prefix}-fastapi-api-logs"
  }
}

# --- Task Definition para la API FastAPI ---
resource "aws_ecs_task_definition" "fastapi_api" {
  family                   = "${local.prefix}-fastapi-api-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.fastapi_cpu
  memory                   = var.fastapi_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn # Rol para que ECS pueda hacer pull de ECR, logs
  task_role_arn            = aws_iam_role.fargate_app_task_role.arn   # Rol para que tu aplicación acceda a otros servicios

  container_definitions = jsonencode([{
    name      = "${local.prefix}-fastapi-container"
    image     = var.fastapi_container_image # e.g., "ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/repo_name:tag"
    cpu       = var.fastapi_cpu
    memory    = var.fastapi_memory
    essential = true
    portMappings = [{
      containerPort = var.fastapi_container_port
      hostPort      = var.fastapi_container_port # En Fargate, hostPort y containerPort suelen ser el mismo
      protocol      = "tcp"
    }]
    environment = [
      { name = "DB_SECRET_ARN", value = aws_secretsmanager_secret.db_credentials.arn },
      { name = "DB_NAME", value = var.db_name},
      { name = "OUTPUT_REPORTS_BUCKET", value = aws_s3_bucket.output_reports.bucket },
      { name = "AWS_REGION", value = var.aws_region },
      { name = "ENVIRONMENT", value = var.environment },
      { name = "FASTAPI_PORT", value = tostring(var.fastapi_container_port) }
      # Añadir más variables de entorno si aplica
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.fargate_api_logs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs" # Prefijo para los streams de logs
      }
    }
  }])

  tags = {
    Name = "${local.prefix}-fastapi-api-task"
  }
}

# --- Application Load Balancer (ALB) ---
resource "aws_lb" "api" {
  name               = "${local.prefix}-api-alb"
  internal           = false # Externo
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id] # ALB en subredes públicas

  enable_deletion_protection = var.environment == "prod"

  tags = {
    Name = "${local.prefix}-api-alb"
  }
}

resource "aws_lb_target_group" "api_fastapi" {
  name        = "${local.prefix}-fastapi-tg"
  port        = var.fastapi_container_port
  protocol    = "HTTP" # Tráfico del ALB al target es HTTP
  vpc_id      = aws_vpc.main.id
  target_type = "ip"  # Para Fargate

  health_check {
    enabled             = true
    path                = "/docs" # Cambiar por un endpoint de health check en la API
    protocol            = "HTTP"
    port                = "traffic-port"
    matcher             = "200-299"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${local.prefix}-fastapi-tg"
  }
}

# Listener HTTP (redirigir a HTTPS en producción)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_fastapi.arn
  }
  # En producción, implementar una acción para redirigir HTTP a HTTPS:
  # default_action {
  #   type = "redirect"
  #   redirect {
  #     port        = "443"
  #     protocol    = "HTTPS"
  #     status_code = "HTTP_301"
  #   }
  # }
}

# (Opcional pero recomendado) Listener HTTPS
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.api.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08" # O una política más reciente
#   certificate_arn   = "arn:aws:acm:REGION:ACCOUNT_ID:certificate/CERTIFICATE_ID" # ARN de tu certificado ACM

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.api_fastapi.arn
#   }
# }


# --- ECS Service para la API FastAPI ---
resource "aws_ecs_service" "fastapi_api" {
  name            = "${local.prefix}-fastapi-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.fastapi_api.arn
  desired_count   = var.environment == "prod" ? 2 : 1 # Mínimo 2 para alta disponibilidad en prod
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [for subnet in aws_subnet.private : subnet.id] # Tareas Fargate en subredes privadas
    security_groups  = [aws_security_group.fargate_tasks.id]
    assign_public_ip = false # Las tareas no necesitan IP pública, acceden via NAT si es necesario
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api_fastapi.arn
    container_name   = "${local.prefix}-fastapi-container" # Mismo nombre que en la task definition
    container_port   = var.fastapi_container_port
  }

  # health_check_grace_period_seconds = 60 # Tiempo para que el servicio se estabilice antes de que el health check falle

  # Para despliegues blue/green o rolling updates
  deployment_controller {
    type = "ECS" # O CODE_DEPLOY
  }
  # deployment_maximum_percent         = 200
  # deployment_minimum_healthy_percent = 50

  depends_on = [aws_lb_listener.http] # O aws_lb_listener.https si lo usas

  tags = {
    Name = "${local.prefix}-fastapi-service"
  }
}

output "api_alb_dns_name" {
  description = "DNS name del Application Load Balancer para la API."
  value       = aws_lb.api.dns_name
}

output "ecr_repository_url_fastapi" {
  description = "URL del repositorio ECR para la API FastAPI."
  value       = aws_ecr_repository.fastapi_api.repository_url
}
