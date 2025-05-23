output "vpc_id" {
  description = "ID de la VPC creada."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs de las subredes públicas."
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet_ids" {
  description = "IDs de las subredes privadas."
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "s3_input_transactions_bucket_name" {
  description = "Nombre del bucket S3 para transacciones de entrada."
  value       = aws_s3_bucket.input_transactions.bucket
}

output "s3_output_reports_bucket_name" {
  description = "Nombre del bucket S3 para reportes de salida."
  value       = aws_s3_bucket.output_reports.bucket
}

output "rds_instance_endpoint" {
  description = "Endpoint de la instancia RDS PostgreSQL."
  value       = aws_db_instance.main_postgres.endpoint
}

output "rds_instance_port" {
  description = "Puerto de la instancia RDS PostgreSQL."
  value       = aws_db_instance.main_postgres.port
}

output "rds_db_credentials_secret_arn_output" { # Renombrado para evitar conflicto con el output en rds.tf si se usan juntos
  description = "ARN del secreto en Secrets Manager para las credenciales de la BD."
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "ingestion_lambda_arn" {
  description = "ARN de la función Lambda de Ingesta."
  value       = aws_lambda_function.ingestion_lambda.arn
}

output "reconciliation_lambda_arn" {
  description = "ARN de la función Lambda de Conciliación/Reporte."
  value       = aws_lambda_function.reconciliation_lambda.arn
}

output "fastapi_ecr_repository_url" {
  description = "URL del repositorio ECR para la API FastAPI."
  value       = aws_ecr_repository.fastapi_api.repository_url # Ya existe en ecs_fargate.tf, puedo centralizarlo
}

output "fastapi_alb_dns" {
  description = "DNS del Application Load Balancer para la API FastAPI."
  value       = aws_lb.api.dns_name # Ya existe en ecs_fargate.tf
}

output "step_functions_state_machine_arn" {
  description = "ARN de la máquina de estados de Step Functions."
  value       = aws_sfn_state_machine.reconciliation_workflow.id
}
