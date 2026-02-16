# EventBridge Custom Event Bus
resource "aws_cloudwatch_event_bus" "main" {
  name = local.event_bus_name

  tags = merge(local.common_tags, {
    Name = local.event_bus_name
  })
}

# Event Archive (optional - for event replay)
resource "aws_cloudwatch_event_archive" "main" {
  count = var.enable_event_archive ? 1 : 0

  name             = "${local.event_bus_name}-archive"
  event_source_arn = aws_cloudwatch_event_bus.main.arn
  retention_days   = var.event_archive_retention_days

  description = "Event archive for ${var.environment} environment (${var.event_archive_retention_days} day retention)"
}

# Event Rules - Route events to SQS queues based on event type

# Rule 1: Route events to OS Service
resource "aws_cloudwatch_event_rule" "to_os_service" {
  name           = "route-to-os-service-${var.environment}"
  description    = "Route BudgetGenerated, PaymentCompleted, ExecutionCompleted events to OS Service"
  event_bus_name = aws_cloudwatch_event_bus.main.name

  event_pattern = jsonencode({
    detail-type = [
      "BudgetGenerated",
      "BudgetApproved",
      "BudgetRejected",
      "PaymentCompleted",
      "PaymentFailed",
      "ExecutionScheduled",
      "ExecutionStarted",
      "ExecutionCompleted",
      "ExecutionFailed"
    ]
  })

  tags = merge(local.common_tags, {
    Name       = "route-to-os-service-${var.environment}"
    TargetService = "os-service"
  })
}

resource "aws_cloudwatch_event_target" "to_os_service" {
  rule           = aws_cloudwatch_event_rule.to_os_service.name
  event_bus_name = aws_cloudwatch_event_bus.main.name
  arn            = aws_sqs_queue.os_service.arn
  target_id      = "os-service-queue"

  # Add dead letter queue for failed deliveries
  dead_letter_config {
    arn = aws_sqs_queue.os_service_dlq.arn
  }

  # Retry policy
  retry_policy {
    maximum_event_age_in_seconds = 3600  # 1 hour
    maximum_retry_attempts  = 3
  }
}

# Rule 2: Route events to Billing Service
resource "aws_cloudwatch_event_rule" "to_billing_service" {
  name           = "route-to-billing-service-${var.environment}"
  description    = "Route OrderCreated, ExecutionCompleted events to Billing Service"
  event_bus_name = aws_cloudwatch_event_bus.main.name

  event_pattern = jsonencode({
    detail-type = [
      "OrderCreated",
      "OrderCancelled",
      "ExecutionCompleted" # For final invoice generation
    ]
  })

  tags = merge(local.common_tags, {
    Name          = "route-to-billing-service-${var.environment}"
    TargetService = "billing-service"
  })
}

resource "aws_cloudwatch_event_target" "to_billing_service" {
  rule           = aws_cloudwatch_event_rule.to_billing_service.name
  event_bus_name = aws_cloudwatch_event_bus.main.name
  arn            = aws_sqs_queue.billing_service.arn
  target_id      = "billing-service-queue"

  dead_letter_config {
    arn = aws_sqs_queue.billing_service_dlq.arn
  }

  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts = 3
  }
}

# Rule 3: Route events to Execution Service
resource "aws_cloudwatch_event_rule" "to_execution_service" {
  name           = "route-to-execution-service-${var.environment}"
  description    = "Route PaymentCompleted events to Execution Service"
  event_bus_name = aws_cloudwatch_event_bus.main.name

  event_pattern = jsonencode({
    detail-type = [
      "PaymentCompleted",
      "BudgetApproved" # Alternative trigger for execution scheduling
    ]
  })

  tags = merge(local.common_tags, {
    Name          = "route-to-execution-service-${var.environment}"
    TargetService = "execution-service"
  })
}

resource "aws_cloudwatch_event_target" "to_execution_service" {
  rule           = aws_cloudwatch_event_rule.to_execution_service.name
  event_bus_name = aws_cloudwatch_event_bus.main.name
  arn            = aws_sqs_queue.execution_service.arn
  target_id      = "execution-service-queue"

  dead_letter_config {
    arn = aws_sqs_queue.execution_service_dlq.arn
  }

  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts = 3
  }
}


# EventBridge to SQS permissions
resource "aws_sqs_queue_policy" "allow_eventbridge_to_os_service" {
  queue_url = aws_sqs_queue.os_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowEventBridgeToSendMessages"
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.os_service.arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = aws_cloudwatch_event_rule.to_os_service.arn
        }
      }
    }]
  })
}

resource "aws_sqs_queue_policy" "allow_eventbridge_to_billing_service" {
  queue_url = aws_sqs_queue.billing_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowEventBridgeToSendMessages"
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.billing_service.arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = aws_cloudwatch_event_rule.to_billing_service.arn
        }
      }
    }]
  })
}

resource "aws_sqs_queue_policy" "allow_eventbridge_to_execution_service" {
  queue_url = aws_sqs_queue.execution_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowEventBridgeToSendMessages"
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.execution_service.arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = aws_cloudwatch_event_rule.to_execution_service.arn
        }
      }
    }]
  })
}
