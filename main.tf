terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.16"
    }
  }

  required_version = ">= 1.2.0"


  backend "s3" {
    bucket         = "tf-backend-571600871147-us-east-1-tfstate" 
    key            = "reconciliation-app/terraform.tfstate" # Ruta dentro del bucket para el estado
    region         = "us-east-1"
    dynamodb_table = "terraform-state-loc" 
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  # Puedes añadir perfiles o roles asumidos aquí si es necesario
  # default_tags {
  #   tags = {
  #     Environment = var.environment
  #     Project     = var.project_name
  #     ManagedBy   = "Terraform"
  #   }
  # }
}

# Para generar nombres únicos y consistentes
locals {
  prefix = "${var.project_name}-${var.environment}"
}
