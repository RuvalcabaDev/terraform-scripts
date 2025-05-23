aws_region             = "us-east-1"
environment            = "dev"
project_name           = "reconciliation"
availability_zones     = ["us-east-1"] 

db_instance_class      = "db.t3.micro"
db_allocated_storage   = 20

fastapi_container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/reconciliation-fastapi-dev:latest" # Ejemplo
