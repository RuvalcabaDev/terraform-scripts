# --- Función Lambda de Ingesta ---
data "archive_file" "ingestion_lambda_zip" {
  type        = "zip"
  source_file = var.lambda_ingestion_zip_path # El archivo .py o el directorio de la función
  output_path = "ingestion_lambda_payload.zip"
}

resource "aws_lambda_function" "ingestion_lambda" {
  function_name    = "${local.prefix}-ingestion-lambda"
  handler          = "ingestion_handler.lambda_handler"
  runtime          = "python3.9"
  role             = aws_iam_role.lambda_execution_role.arn # Usar el rol general o uno específico
  # filename         = data.archive_file.ingestion_lambda_zip.output_path
  # source_code_hash = data.archive_file.ingestion_lambda_zip.output_base64sha256
  s3_bucket = aws_s3_bucket.lambda_artifacts.id # Asume que subes el zip a este bucket
  s3_key    = "ingestion_lambda.zip"          # Nombre del objeto en S3

  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  # Configuración de VPC para acceder a RDS
  vpc_config {
    subnet_ids         = [for subnet in aws_subnet.private : subnet.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DB_SECRET_ARN        = aws_secretsmanager_secret.db_credentials.arn
      DB_NAME              = var.db_name
      DB_HOST              = aws_db_instance.main_postgres.endpoint
      DB_PORT              = aws_db_instance.main_postgres.port
      ENVIRONMENT          = var.environment

    }
  }

  # tracing_config {
  #   mode = "Active" # Habilitar AWS X-Ray
  # }

  tags = {
    Name = "${local.prefix}-ingestion-lambda"
  }
  # depends_on = [aws_iam_role_policy_attachment.lambda_ingestion_attach] # Asegura que la política esté adjunta
}

# Trigger S3 para la Lambda de Ingesta
resource "aws_s3_bucket_notification" "input_bucket_notification" {
  bucket = aws_s3_bucket.input_transactions.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.ingestion_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "input/" # Opcional: si los archivos están en un prefijo
    filter_suffix       = ".csv"   # Opcional: si solo quieres CSVs
  }
  depends_on = [aws_lambda_permission.s3_allow_lambda_invoke]
}

resource "aws_lambda_permission" "s3_allow_lambda_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingestion_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.input_transactions.arn
}


# --- Función Lambda de Conciliación y Reporte ---
data "archive_file" "reconciliation_lambda_zip" {
  type        = "zip"
  source_file = var.lambda_reconciliation_zip_path
  output_path = "reconciliation_lambda_payload.zip"
}

resource "aws_lambda_function" "reconciliation_lambda" {
  function_name    = "${local.prefix}-reconciliation-lambda"
  handler          = "reconciliation_handler.lambda_handler"
  runtime          = "python3.9"
  role             = aws_iam_role.lambda_execution_role.arn # Usar el rol general o uno específico

  # filename         = data.archive_file.reconciliation_lambda_zip.output_path
  # source_code_hash = data.archive_file.reconciliation_lambda_zip.output_base64sha256
  s3_bucket = aws_s3_bucket.lambda_artifacts.id
  s3_key    = "reconciliation_lambda.zip"

  timeout          = var.lambda_timeout * 2 # Podría necesitar más tiempo
  memory_size      = var.lambda_memory_size * 2 # Podría necesitar más memoria

  vpc_config {
    subnet_ids         = [for subnet in aws_subnet.private : subnet.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DB_SECRET_ARN           = aws_secretsmanager_secret.db_credentials.arn
      DB_NAME                 = var.db_name
      DB_HOST                 = aws_db_instance.main_postgres.endpoint
      DB_PORT                 = aws_db_instance.main_postgres.port
      OUTPUT_REPORTS_BUCKET   = aws_s3_bucket.output_reports.bucket
      ENVIRONMENT             = var.environment
    }
  }

  # tracing_config {
  #   mode = "Active"
  # }

  tags = {
    Name = "${local.prefix}-reconciliation-lambda"
  }
  # depends_on = [aws_iam_role_policy_attachment.lambda_reconciliation_attach]
}
