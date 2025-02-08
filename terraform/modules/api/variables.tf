variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev/prod)"
  type        = string
}

variable "lambda_get_questions_arn" {
  description = "ARN of get questions Lambda function"
  type        = string
}

variable "lambda_get_questions_name" {
  description = "Name of get questions Lambda function"
  type        = string
}

variable "lambda_websocket_arn" {
  description = "ARN of WebSocket Lambda function"
  type        = string
}

variable "lambda_websocket_name" {
  description = "Name of WebSocket Lambda function"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}