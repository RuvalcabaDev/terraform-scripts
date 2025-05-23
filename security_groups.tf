# Security Group para el ALB (Fargate)
resource "aws_security_group" "alb" {
  name        = "${local.prefix}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Acceso HTTP desde cualquier lugar
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Acceso HTTPS desde cualquier lugar
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Permite todo el tráfico saliente
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.prefix}-alb-sg" }
}

# Security Group para las tareas Fargate (API FastAPI)
resource "aws_security_group" "fargate_tasks" {
  name        = "${local.prefix}-fargate-sg"
  description = "Security group for Fargate tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow traffic from ALB"
    from_port       = var.fastapi_container_port
    to_port         = var.fastapi_container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id] # Solo permite tráfico desde el ALB
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Permite a las tareas acceder a S3, RDS, Secrets Manager, etc.
  }

  tags = { Name = "${local.prefix}-fargate-sg" }
}

# Security Group para la instancia RDS
resource "aws_security_group" "rds" {
  name        = "${local.prefix}-rds-sg"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.main.id

  # Permite acceso desde las tareas Fargate
  ingress {
    description     = "PostgreSQL from Fargate"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.fargate_tasks.id]
  }

  # Permite acceso desde las funciones Lambda
  # (Crearemos un SG para Lambdas o usaremos el SG por defecto de la VPC para ellas,
  # y luego referenciaremos ese SG aquí)
   ingress {
     description     = "PostgreSQL from Lambda SG"
     from_port       = 5432
     to_port         = 5432
     protocol        = "tcp"
     security_groups = [aws_security_group.lambda.id] # Referencia al SG de Lambda
   }

  # Permite acceso desde clientes externos (para desarrollo y pruebas)
  ingress {
    description     = "PostgreSQL from external clients"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"] # Permite conexiones desde cualquier IP
  }

  # Egress usualmente no necesita ser restringido para RDS, pero podría si es necesario

  tags = { Name = "${local.prefix}-rds-sg" }
}


# Security Group para las funciones Lambda
resource "aws_security_group" "lambda" {
  name        = "${local.prefix}-lambda-sg"
  description = "Security group for Lambda functions within VPC"
  vpc_id      = aws_vpc.main.id

  # Egress: Permite a Lambda acceder a otros servicios AWS (S3, RDS, Secrets Manager)
  # y a internet a través del NAT Gateway si está en subred privada.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.prefix}-lambda-sg" }
}
