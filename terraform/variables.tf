variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name to be used for resource naming"
  type        = string
  default     = "kahoot-like"
}

variable "environment" {
  description = "Environment (dev/prod)"
  type        = string
  default     = "dev"
}

variable "github_repository_frontend" {
  description = "GitHub repository for frontend (format: username/repository)"
  type        = string
}

variable "github_branch_frontend" {
  description = "GitHub branch for frontend"
  type        = string
  default     = "main"
}

variable "website_bucket_name" {
  description = "Name of the S3 bucket for website hosting"
  type        = string
}

variable "artifacts_bucket_name" {
  description = "Name of the S3 bucket for build artifacts"
  type        = string
}

variable "lambda_runtime" {
  description = "Runtime for Lambda functions"
  type        = string
  default     = "nodejs20.x"
}