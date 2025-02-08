variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev/prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "lambda_runtime" {
  description = "Runtime for Lambda functions"
  type        = string
}

variable "websocket_api_id" {
  description = "WebSocket API ID"
  type        = string
}

variable "websocket_stage_name" {
  description = "WebSocket API stage name"
  type        = string
}

variable "websocket_stage_url" {
  description = "WebSocket stage URL"
  type        = string
}

variable "questions_table_arn" {
  description = "Questions table ARN"
  type        = string
}

variable "connections_table_arn" {
  description = "Connections table ARN"
  type        = string
}

variable "games_table_arn" {
  description = "Games table ARN"
  type        = string
}

variable "answers_table_arn" {
  description = "Answers table ARN"
  type        = string
}

variable "sqs_queue_arn" {
  description = "SQS queue ARN"
  type        = string
}

variable "sqs_queue_url" {
  description = "SQS queue URL"
  type        = string
}

variable "lambda_artifacts_dir" {
  description = "Directory for Lambda zip artifacts"
  type        = string
  default     = "lambda_artifacts"
}