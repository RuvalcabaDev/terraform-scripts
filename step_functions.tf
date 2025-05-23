resource "aws_sfn_state_machine" "reconciliation_workflow" {
  name     = "${local.prefix}-ReconciliationWorkflow"
  role_arn = aws_iam_role.step_functions_execution_role.arn # Rol definido en iam.tf

  # Definición de la máquina de estados en Amazon States Language (ASL)
  # Esta es una definición de ejemplo. Deberás ajustarla a tus necesidades exactas.
  definition = jsonencode({
    Comment = "Flujo de trabajo para la conciliación de transacciones"
    StartAt = "TriggerIngestionOrGetData" # O "ProcessS3File" si la Lambda de ingesta es el primer paso directo
    States = {
      TriggerIngestionOrGetData = {
        Type = "Choice"
        Choices = [
          {
            # Si el input a Step Functions incluye un S3 object (evento de S3)
            Variable = "$.Records[0].s3.object.key" 
            IsPresent = true
            Next = "ProcessS3File"
          }
        ]
        Default = "GetPendingDateToReconcile" # Si se ejecuta de forma programada
      }
      GetPendingDateToReconcile = {
        # Se puede tener una Lambda aquí que determine la fecha
        # o pasar la fecha como input al iniciar la máquina de estados
        Type = "Pass" 
        Result = { 
          # Ejemplo: Configurar esto dinámicamente
          reconciliation_date = formatdate("YYYY-MM-DD", timeadd(timestamp(), "-24h"))
        }
        ResultPath = "$.reconciliationInfo"
        Next = "CheckIfAlreadyProcessed"
      }
      CheckIfAlreadyProcessed = {
        # Lambda para verificar si la fecha ya fue procesada (consulta reconciliation_reports)
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke" # Usar Lambda para chequear
        Parameters = {
          FunctionName = aws_lambda_function.reconciliation_lambda.function_name # O una lambda específica para esto
          Payload = {
            "action" = "check_status"
            "date.$" = "$.reconciliationInfo.reconciliation_date"
          }
        }
        ResultPath = "$.processingStatus"
        Next = "IsProcessingNeeded"
      }
      IsProcessingNeeded = {
        Type = "Choice"
        Choices = [
          {
            Variable = "$.processingStatus.needs_processing" # Asume que la Lambda devuelve esto
            BooleanEquals = true
            Next = "ProcessS3File" # Asume que la ingesta es el primer paso real del procesamiento de datos
          }
        ]
        Default = "SkipProcessing"
      }
      ProcessS3File = { # Este estado podría ser la Lambda de Ingesta
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke" # Usar Lambda para ingesta
        # O podrías tener la Lambda de Ingesta fuera de Step Functions,
        # y esta máquina solo se encarga de Conciliación y Reporte.
        # Si la ingesta es independiente:
        #   - S3 -> Lambda (Ingesta) -> Guarda en DB Intermedia -> (Opcional) Envía evento/mensaje
        #   - Step Functions (Conciliación) -> Lee DB Intermedia -> ...
        # Si la ingesta es parte de Step Functions:
        Parameters = {
          FunctionName = aws_lambda_function.ingestion_lambda.function_name
          # El payload para la ingesta puede venir del trigger S3 o ser construido aquí
          "Payload.$" = "$" 
        }
        Retry = [{
          ErrorEquals = ["States.TaskFailed", "Lambda.ServiceException", "Lambda.SdkClientException"]
          IntervalSeconds = 2
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "IngestionFailed"
          ResultPath  = "$.errorInfo"
        }]
        ResultPath = "$.ingestionResult" # Guarda el resultado de la ingesta
        Next     = "RunReconciliation"
      }
      RunReconciliation = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke" # Usar Lambda para conciliación y reporte
        Parameters = {
          FunctionName = aws_lambda_function.reconciliation_lambda.function_name
          Payload = {
            # "ingestion_output.$" = "$.ingestionResult"
            "date_to_reconcile.$" = "$.reconciliationInfo.reconciliation_date" # O la fecha de los datos ingeridos
          }
        }
        Retry = [{
          ErrorEquals = ["States.TaskFailed", "Lambda.ServiceException", "Lambda.SdkClientException"],
          IntervalSeconds = 10,
          MaxAttempts     = 2,
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"],
          Next        = "ReconciliationFailed",
          ResultPath  = "$.errorInfo"
        }]
        Next     = "ReconciliationSucceeded"
      }
      IngestionFailed = {
        Type = "Fail"
        Error = "IngestionProcessFailed"
        CausePath = "$.errorInfo"
      }
      ReconciliationFailed = {
        Type = "Fail" # O podrías tener un estado de notificación
        Error = "ReconciliationProcessFailed"
        CausePath = "$.errorInfo" # Contiene la información del error de la Lambda
      }
      ReconciliationSucceeded = {
        Type = "Succeed"
      }
      SkipProcessing = {
        Type = "Succeed" # O un Pass para loggear y luego Succeed
      }
    }
  })

  # Para logging de ejecución de Step Functions (opcional pero recomendado)
  # logging_configuration {
  #   log_destination        = "${aws_cloudwatch_log_group.sfn_logs.arn}:*"
  #   include_execution_data = true
  #   level                  = "ALL"
  # }

  tags = {
    Name = "${local.prefix}-ReconciliationWorkflow"
  }
}

# (Opcional) Log Group para Step Functions
# resource "aws_cloudwatch_log_group" "sfn_logs" {
#   name = "/aws/vendedlogs/states/${local.prefix}-ReconciliationWorkflow-logs"
#   retention_in_days = 7
# }

# Trigger de EventBridge para ejecutar la máquina de estados diariamente
resource "aws_cloudwatch_event_rule" "daily_reconciliation_trigger" {
  name                = "${local.prefix}-DailyReconciliationTrigger"
  description         = "Dispara la máquina de estados de conciliación diariamente"
  schedule_expression = "cron(0 5 * * ? *)" # Todos los días a las 5 AM UTC. Ajusta.
  # Ejemplo: "cron(0 10 ? * MON-FRI *)" -> Lunes a Viernes a las 10:00 AM UTC

  tags = {
    Name = "${local.prefix}-DailyReconciliationTrigger"
  }
}

resource "aws_cloudwatch_event_target" "sfn_target" {
  rule     = aws_cloudwatch_event_rule.daily_reconciliation_trigger.name
  arn      = aws_sfn_state_machine.reconciliation_workflow.id
  role_arn = aws_iam_role.eventbridge_to_sfn_role.arn # Necesitas un rol para que EventBridge pueda iniciar SFN

  # Puedes pasar un input constante o dinámico aquí si es necesario
  # input = jsonencode({
  #   "source" : "aws.events"
  # })
}

# Rol para que EventBridge pueda iniciar la máquina de estados
resource "aws_iam_role" "eventbridge_to_sfn_role" {
  name = "${local.prefix}-eventbridge-to-sfn-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "events.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "eventbridge_sfn_start_execution_policy" {
  name   = "${local.prefix}-eventbridge-sfn-start-policy"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "states:StartExecution",
      Resource = aws_sfn_state_machine.reconciliation_workflow.id
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eventbridge_sfn_start_attach" {
  role       = aws_iam_role.eventbridge_to_sfn_role.name
  policy_arn = aws_iam_policy.eventbridge_sfn_start_execution_policy.arn
}
