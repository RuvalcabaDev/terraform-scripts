variable "aws_region" {
  description = "Región de AWS para desplegar los recursos."
  type        = string
  default     = "us-east-1" 
}

variable "environment" {
  description = "Entorno de despliegue (dev, staging, prod)."
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "El entorno debe ser dev, staging, o prod."
  }
}

variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo para los recursos."
  type        = string
  default     = "reconciliation"
}

variable "vpc_cidr_block" {
  description = "Bloque CIDR para la VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Lista de bloques CIDR para las subredes públicas."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Lista de bloques CIDR para las subredes privadas."
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "availability_zones" {
  description = "Zonas de disponibilidad a usar."
  type        = list(string)
  # Asegúrate que estas AZs existan en tu var.aws_region
  # Puedes obtenerlas con `aws ec2 describe-availability-zones --region tu-region`
  # default     = ["us-east-1a", "us-east-1b"] # AJUSTA ESTO
}

variable "db_instance_class" {
  description = "Clase de instancia para RDS."
  type        = string
  default     = "db.t3.micro" # Según tus necesidades y presupuesto
}

variable "db_allocated_storage" {
  description = "Almacenamiento alocado para RDS en GB."
  type        = number
  default     = 20
}

variable "db_engine_version_postgres" {
  description = "Versión del motor PostgreSQL para RDS."
  type        = string
  default     = "17"
}

variable "db_name" {
  description = "Nombre de la base de datos principal en RDS donde residirán todas las tablas del proyecto."
  type        = string
  default     = "reconciliation_db" 
}

variable "db_username" {
  description = "Nombre de usuario para la instancia RDS (se guardará en Secrets Manager)."
  type        = string
  default     = "dbadmin"
  sensitive   = true
}

# La contraseña se generará aleatoriamente por Secrets Manager

variable "lambda_memory_size" {
  description = "Memoria asignada a las funciones Lambda (MB)."
  type        = number
  default     = 256
}

variable "lambda_timeout" {
  description = "Timeout para las funciones Lambda (segundos)."
  type        = number
  default     = 30
}

variable "fastapi_container_image" {
  description = "URI de la imagen Docker en ECR para la API FastAPI."
  type        = string
  default     = "571600871147.dkr.ecr.us-east-1.amazonaws.com/reconciliation-dev-fastapi-api-repo:latest"
}

variable "fastapi_container_port" {
  description = "Puerto en el que la aplicación FastAPI escucha dentro del contenedor."
  type        = number
  default     = 8000
}

variable "fastapi_cpu" {
  description = "Unidades de CPU para la tarea Fargate (e.g., 256, 512, 1024)."
  type        = number
  default     = 512 # 0.5 vCPU
}

variable "fastapi_memory" {
  description = "Memoria en MiB para la tarea Fargate (e.g., 512, 1024, 2048)."
  type        = number
  default     = 1024 # 1 GB
}

# Para los archivos Lambda ZIP
variable "lambda_ingestion_zip_path" {
  description = "Ruta al archivo ZIP de la función Lambda de Ingesta."
  type        = string
  default     = "ingestion_lambda.zip"
}

variable "lambda_reconciliation_zip_path" {
  description = "Ruta al archivo ZIP de la función Lambda de Conciliación/Reporte."
  type        = string
  default     = "reconciliation_lambda.zip"
}
