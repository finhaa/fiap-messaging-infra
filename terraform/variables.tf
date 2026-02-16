variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name (used for resource naming)"
  type        = string
  default     = "fiap-tech-challenge"
}

variable "environment" {
  description = "Environment name (development, production)"
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "production"], var.environment)
    error_message = "Environment must be one of: development, production"
  }
}

variable "message_retention_seconds" {
  description = "SQS message retention period in seconds (4 days default)"
  type        = number
  default     = 345600 # 4 days
}

variable "visibility_timeout_seconds" {
  description = "SQS visibility timeout in seconds (5 minutes default)"
  type        = number
  default     = 300
}

variable "max_receive_count" {
  description = "Maximum number of times a message can be received before moving to DLQ"
  type        = number
  default     = 3
}

variable "enable_event_archive" {
  description = "Enable EventBridge event archive for replay capability"
  type        = bool
  default     = false # Set to true for production
}

variable "event_archive_retention_days" {
  description = "Number of days to retain events in archive"
  type        = number
  default     = 90
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for monitoring"
  type        = bool
  default     = true
}

variable "alarm_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
  default     = ""
}
