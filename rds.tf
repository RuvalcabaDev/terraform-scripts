resource "aws_db_subnet_group" "main" {
  name       = "${local.prefix}-rds-subnet-group"
  subnet_ids = [for subnet in aws_subnet.public : subnet.id] # RDS en subredes públicas para permitir acceso externo

  tags = {
    Name = "${local.prefix}-rds-subnet-group"
  }
}

resource "aws_db_instance" "main_postgres" {
  identifier             = "${local.prefix}-main-db"
  allocated_storage      = var.db_allocated_storage
  engine                 = "postgres"
  engine_version         = var.db_engine_version_postgres
  instance_class         = var.db_instance_class
  # Multi-AZ para producción:
  # multi_az               = var.environment == "prod" ? true : false

  db_name                = var.db_name # Base de datos por defecto que se crea

  username               = jsondecode(aws_secretsmanager_secret_version.db_credentials_version.secret_string).username
  password               = jsondecode(aws_secretsmanager_secret_version.db_credentials_version.secret_string).password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  parameter_group_name   = "default.postgres${var.db_engine_version_postgres}" # Puedes crear uno personalizado
  # option_group_name      = "default:postgres-${var.db_engine_version_postgres}" # Puedes crear uno personalizado

  skip_final_snapshot    = var.environment == "dev" # En prod, no omitir
  # deletion_protection    = var.environment == "prod" # Proteger contra borrado en prod

  # Backup y mantenimiento
  backup_retention_period = var.environment == "prod" ? 7 : 0 # 0 deshabilita backups automáticos (no recomendado para prod)
  # backup_window           = "03:00-04:00"
  # maintenance_window      = "Sun:05:00-Sun:06:00"

  # Para que las Lambdas y Fargate puedan encontrarlo
  publicly_accessible   = true # solo para pruebas

  tags = {
    Name = "${local.prefix}-main-db"
  }
}

# Output del endpoint de RDS para usar en la configuración de la aplicación
output "db_endpoint" {
  description = "Endpoint de la instancia RDS."
  value       = aws_db_instance.main_postgres.endpoint
}

output "db_port" {
  description = "Puerto de la instancia RDS."
  value       = aws_db_instance.main_postgres.port
}

output "db_credentials_secret_arn" {
  description = "ARN del secreto en Secrets Manager para las credenciales de la BD."
  value       = aws_secretsmanager_secret.db_credentials.arn
}
