# CloudWatch Monitoring for Messaging Infrastructure

# SNS Topic for Alarms (if email provided)
resource "aws_sns_topic" "alarms" {
  count = var.enable_cloudwatch_alarms && var.alarm_email != "" ? 1 : 0

  name = "${var.project_name}-messaging-alarms-${var.environment}"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-messaging-alarms-${var.environment}"
  })
}

resource "aws_sns_topic_subscription" "alarm_email" {
  count = var.enable_cloudwatch_alarms && var.alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# CloudWatch Alarms - Queue Depth (Backlog Alert)

resource "aws_cloudwatch_metric_alarm" "os_service_queue_depth" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "os-service-queue-depth-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300 # 5 minutes
  statistic           = "Average"
  threshold           = 1000
  alarm_description   = "Alert when OS Service queue has more than 1000 messages (backlog)"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.os_service.name
  }

  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "billing_service_queue_depth" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "billing-service-queue-depth-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 1000
  alarm_description   = "Alert when Billing Service queue has more than 1000 messages"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.billing_service.name
  }

  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "execution_service_queue_depth" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "execution-service-queue-depth-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 1000
  alarm_description   = "Alert when Execution Service queue has more than 1000 messages"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.execution_service.name
  }

  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = local.common_tags
}

# CloudWatch Alarms - DLQ Has Messages (Failed Processing Alert)

resource "aws_cloudwatch_metric_alarm" "os_service_dlq_messages" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "os-service-dlq-has-messages-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when OS Service DLQ has failed messages"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.os_service_dlq.name
  }

  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "billing_service_dlq_messages" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "billing-service-dlq-has-messages-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when Billing Service DLQ has failed messages"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.billing_service_dlq.name
  }

  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "execution_service_dlq_messages" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "execution-service-dlq-has-messages-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when Execution Service DLQ has failed messages"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.execution_service_dlq.name
  }

  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = local.common_tags
}

# CloudWatch Alarms - Old Messages (Slow Processing Alert)

resource "aws_cloudwatch_metric_alarm" "os_service_old_messages" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "os-service-old-messages-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 300 # 5 minutes
  alarm_description   = "Alert when OS Service has messages older than 5 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.os_service.name
  }

  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = local.common_tags
}

# CloudWatch Dashboard

resource "aws_cloudwatch_dashboard" "messaging" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  dashboard_name = "${var.project_name}-messaging-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 24
        height = 6
        properties = {
          metrics = [
            ["AWS/SQS", "NumberOfMessagesSent", "QueueName", aws_sqs_queue.os_service.name],
            ["AWS/SQS", "NumberOfMessagesSent", "QueueName", aws_sqs_queue.billing_service.name],
            ["AWS/SQS", "NumberOfMessagesSent", "QueueName", aws_sqs_queue.execution_service.name]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Messages Sent to Queues"
        }
      },
      {
        type   = "metric"
        width  = 24
        height = 6
        properties = {
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.os_service.name],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.billing_service.name],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.execution_service.name]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Queue Depth (Messages Waiting)"
        }
      },
      {
        type   = "metric"
        width  = 24
        height = 6
        properties = {
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.os_service_dlq.name],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.billing_service_dlq.name],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.execution_service_dlq.name]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Dead Letter Queues (Failed Messages)"
        }
      }
    ]
  })
}
