# --- Rol para Lambdas ---
resource "aws_iam_role" "lambda_execution_role" {
  name = "${local.prefix}-lambda-execution-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
  tags = { Name = "${local.prefix}-lambda-exec-role" }
}

# Política base para logs de Lambda y acceso a VPC
resource "aws_iam_policy" "lambda_base_policy" {
  name        = "${local.prefix}-lambda-base-policy"
  description = "Política base para que las Lambdas escriban logs y accedan a VPC"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses", # Necesario si la Lambda se conecta a RDS en VPC
          "ec2:UnassignPrivateIpAddresses"
        ],
        Resource = "*" # Restringir si es posible
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "lambda_base_attach" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_base_policy.arn
}

# Política para Lambda de Ingesta (S3 read, RDS write via SecretsManager)
resource "aws_iam_policy" "lambda_ingestion_policy" {
  name        = "${local.prefix}-lambda-ingestion-policy"
  description = "Política para la Lambda de ingesta"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:GetObject"],
        Resource = ["${aws_s3_bucket.input_transactions.arn}/*"]
      },
      { # Permiso para leer el secreto de la BD
        Effect   = "Allow",
        Action   = ["secretsmanager:GetSecretValue"],
        Resource = [aws_secretsmanager_secret.db_credentials.arn]
      }
      # Aquí se añadiría el permiso para conectarse a RDS si es necesario
      # (generalmente manejado por el security group y la conectividad VPC)
      # pero si se usa RDS Data API, se requiere permisos para rds-data:*
    ]
  })
}
resource "aws_iam_role_policy_attachment" "lambda_ingestion_attach" {
  role       = aws_iam_role.lambda_execution_role.name # O un rol más específico para esta lambda
  policy_arn = aws_iam_policy.lambda_ingestion_policy.arn
}


# Política para Lambda de Conciliación (S3 write, RDS read/write via SecretsManager)
resource "aws_iam_policy" "lambda_reconciliation_policy" {
  name        = "${local.prefix}-lambda-reconciliation-policy"
  description = "Política para la Lambda de conciliación y reporte"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:PutObject", "s3:GetObject"], # GetObject si lee de la intermedia también
        Resource = ["${aws_s3_bucket.output_reports.arn}/*"]
      },
      {
        Effect   = "Allow",
        Action   = ["secretsmanager:GetSecretValue"],
        Resource = [aws_secretsmanager_secret.db_credentials.arn]
      }
      # Permisos para Step Functions si esta Lambda es parte de un flujo
      # {
      #   Effect = "Allow",
      #   Action = ["states:SendTaskSuccess", "states:SendTaskFailure", "states:SendTaskHeartbeat"],
      #   Resource = "*" # Limitar al ARN de la máquina de estados
      # }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "lambda_reconciliation_attach" {
  role       = aws_iam_role.lambda_execution_role.name # O un rol más específico
  policy_arn = aws_iam_policy.lambda_reconciliation_policy.arn
}


# --- Rol para Tareas ECS Fargate ---
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${local.prefix}-ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = { Name = "${local.prefix}-ecs-task-exec-role" }
}

# Política gestionada por AWS para la ejecución de tareas ECS (pull de ECR, logs)
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Rol para la Tarea Fargate en sí (para que la aplicación acceda a otros servicios)
resource "aws_iam_role" "fargate_app_task_role" {
  name = "${local.prefix}-fargate-app-task-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = { Name = "${local.prefix}-fargate-app-task-role" }
}

resource "aws_iam_policy" "fargate_app_task_policy" {
  name        = "${local.prefix}-fargate-app-task-policy"
  description = "Política para que la aplicación Fargate acceda a RDS y S3"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:GetObject", "s3:ListBucket"], # Para leer reportes de S3
        Resource = [
          aws_s3_bucket.output_reports.arn,
          "${aws_s3_bucket.output_reports.arn}/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = ["secretsmanager:GetSecretValue"],
        Resource = [aws_secretsmanager_secret.db_credentials.arn]
      }
      # Acceso a CloudWatch Logs ya cubierto por AmazonECSTaskExecutionRolePolicy
    ]
  })
}
resource "aws_iam_role_policy_attachment" "fargate_app_task_policy_attach" {
  role       = aws_iam_role.fargate_app_task_role.name
  policy_arn = aws_iam_policy.fargate_app_task_policy.arn
}


# --- Rol para Step Functions ---
resource "aws_iam_role" "step_functions_execution_role" {
  name = "${local.prefix}-step-functions-execution-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "states.${var.aws_region}.amazonaws.com" } 
    }]
  })
  tags = { Name = "${local.prefix}-sfn-exec-role" }
}

resource "aws_iam_policy" "step_functions_lambda_invoke_policy" {
  name        = "${local.prefix}-step-functions-lambda-invoke-policy"
  description = "Política para que Step Functions invoque Lambdas"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "lambda:InvokeFunction",
      Resource = [ 
        # Lista de ARNs de Lambdas
        aws_lambda_function.ingestion_lambda.arn,
        aws_lambda_function.reconciliation_lambda.arn
      ]
    }]
  })
}
resource "aws_iam_role_policy_attachment" "step_functions_lambda_invoke_attach" {
  role       = aws_iam_role.step_functions_execution_role.name
  policy_arn = aws_iam_policy.step_functions_lambda_invoke_policy.arn
}

# Si Step Functions también necesita iniciar ejecuciones de otras Step Functions,
# o interactuar con otros servicios como SNS, SQS, etc., añade esos permisos.
# Para X-Ray tracing:
# resource "aws_iam_role_policy_attachment" "sfn_xray_policy_attach" {
#   role       = aws_iam_role.step_functions_execution_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
# }
