terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend S3 - bucket configured dynamically via terraform init -backend-config
  backend "s3" {
    key            = "messaging-infra/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "fiap-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "messaging-infra"
      Phase       = "Phase-4"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Phase       = "Phase-4"
  }

  # Event bus name
  event_bus_name = "${var.project_name}-events-${var.environment}"

  # Queue names
  queue_names = {
    os_service        = "os-service-events-${var.environment}"
    billing_service   = "billing-service-events-${var.environment}"
    execution_service = "execution-service-events-${var.environment}"
  }

  # DLQ names
  dlq_names = {
    os_service        = "os-service-events-dlq-${var.environment}"
    billing_service   = "billing-service-events-dlq-${var.environment}"
    execution_service = "execution-service-events-dlq-${var.environment}"
  }
}
