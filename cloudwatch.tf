# Los Log Groups para Lambda y Fargate se crean en sus respectivos archivos (lambda.tf, ecs_fargate.tf)

# Ejemplo de Alarma para errores en Lambda de Ingesta
resource "aws_cloudwatch_metric_alarm" "ingestion_lambda_errors" {
  alarm_name          = "${local.prefix}-ingestion-lambda-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60" # 1 minuto
  statistic           = "Sum"
  threshold           = "1" # Alarma si hay 1 o más errores en el periodo
  alarm_description   = "Alarma cuando la Lambda de ingesta tiene errores."
  # dimensions = { # Esto es importante para apuntar a la función correcta
  #   FunctionName = aws_lambda_function.ingestion_lambda.function_name
  # }

  # Acciones de alarma (e.g., notificar a un tópico SNS)
  # alarm_actions = [aws_sns_topic.alarms.arn]
  # ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Name = "${local.prefix}-ingestion-lambda-errors-alarm"
  }
}

# Ejemplo de Alarma para CPU alta en Fargate
resource "aws_cloudwatch_metric_alarm" "fargate_cpu_high" {
  alarm_name          = "${local.prefix}-fargate-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300" # 5 minutos
  statistic           = "Average"
  threshold           = "80"  # Alarma si la CPU promedio es >= 80% durante 10 minutos (2 periodos)
  alarm_description   = "Alarma cuando la utilización de CPU del servicio Fargate es alta."
  # dimensions = { # Apuntar al cluster y servicio correctos
  #   ClusterName = aws_ecs_cluster.main.name
  #   ServiceName = aws_ecs_service.fastapi_api.name
  # }

  # alarm_actions = [aws_sns_topic.alarms.arn]
  # ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Name = "${local.prefix}-fargate-cpu-high-alarm"
  }
}

# (Opcional) Tópico SNS para alarmas
# resource "aws_sns_topic" "alarms" {
#   name = "${local.prefix}-alarms-topic"
# }
# resource "aws_sns_topic_subscription" "alarms_email_target" {
#   topic_arn = aws_sns_topic.alarms.arn
#   protocol  = "email"
#   endpoint  = "tu-email@example.com" # Reemplaza con tu email
# }
