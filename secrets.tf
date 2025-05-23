resource "random_password" "db_password" {
  length           = 16
  special          = false
  upper            = true
  lower            = true
  numeric          = true
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${local.prefix}/rds/main-db-credentials-v2"
  description = "Credenciales para la base de datos principal RDS"
  # recovery_window_in_days = 7 # Para entornos de producción
  tags = {
    Name = "${local.prefix}-rds-creds"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    # host se obtendrá del output de RDS
    # port = 5432
    # dbname = var.db_name
    # engine = "postgres"
  })
}
