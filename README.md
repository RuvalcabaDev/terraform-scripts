# Terraform Deployment Script

Este repositorio contiene un script de Terraform para gestionar la infraestructura en aws del business case.

## Requisitos Previos

Antes de comenzar, asegúrate de tener lo siguiente instalado y configurado:

1. **Terraform**: Descárgalo desde [terraform.io](https://www.terraform.io/downloads.html) e instálalo.
2. **AWS CLI**: Configura las credenciales de AWS con permisos adecuados para gestionar recursos.
3. **PowerShell**: Necesario para ejecutar los scripts proporcionados.

## Estructura del Proyecto

El proyecto tiene la siguiente estructura:

```plaintext
terraform_script/
├── cloudwatch.tf
├── ecs_fargate.tf
├── iam.tf
├── ingestion_handler.py
├── ingestion_lambda_payload.zip
├── ingestion_lambda.zip
├── lambda.tf
├── main.tf
├── outputs.tf
├── rds.tf
├── reconciliation_handler.py
├── reconciliation_lambda_payload.zip
├── reconciliation_lambda.zip
├── s3.tf
├── secrets.tf
├── security_groups.tf
├── step_functions.tf
├── variables.tf
├── vpc.tf
└── environments/
    └── dev.tfvars
```

## Pasos de Instalación

1. **Clona el Repositorio**

   ```bash
   git clone <URL_DEL_REPOSITORIO>
   cd terraform_script
   ```

2. **Configura las Variables de Entorno**

   Modifica el archivo `environments/dev.tfvars` con los valores específicos de tu entorno.

3. **Crea la Tabla DynamoDB para el Bloqueo de Estado (Opcional)**

   - **En Windows (PowerShell):**

     ```powershell
     .\create_dynamodb_table.ps1
     ```

   - **En macOS/Linux (Terminal):**

     Ejecuta manualmente los comandos necesarios para crear la tabla DynamoDB. Por ejemplo:

     ```bash
     aws dynamodb create-table \
       --table-name terraform-state-loc \
       --attribute-definitions AttributeName=LockID,AttributeType=S \
       --key-schema AttributeName=LockID,KeyType=HASH \
       --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
     ```

   Esto creará una tabla DynamoDB llamada `terraform-state-loc`.

4. **Aplica la Configuración de Terraform**

   - **En Windows (PowerShell):**

     ```powershell
     terraform init
     terraform apply -var-file=environments/dev.tfvars
     ```

     Si no puedes usar la tabla DynamoDB, puedes deshabilitar el bloqueo de estado con:

     ```powershell
     terraform apply -lock=false -var-file=environments/dev.tfvars
     ```

   - **En macOS/Linux (Terminal):**

     ```bash
     terraform init
     terraform apply -var-file=environments/dev.tfvars
     ```

     Si no puedes usar la tabla DynamoDB, puedes deshabilitar el bloqueo de estado con:

     ```bash
     terraform apply -lock=false -var-file=environments/dev.tfvars
     ```

## Notas Importantes

- **Bloqueo de Estado**: Se recomienda habilitar el bloqueo de estado para evitar modificaciones concurrentes.
- **Entornos de Desarrollo**: Usa `-lock=false` solo en entornos de desarrollo o pruebas.
