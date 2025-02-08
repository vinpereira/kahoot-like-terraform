variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "aws_profile" {
  description = "AWS profile"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev/prod)"
  type        = string
}

variable "github_repository_frontend" {
  description = "GitHub repository for frontend"
  type        = string
}

variable "github_branch_frontend" {
  description = "GitHub branch for frontend"
  type        = string
}

variable "website_bucket_name" {
  description = "S3 bucket name for website hosting"
  type        = string
}

variable "artifacts_bucket_name" {
  description = "S3 bucket name for build artifacts"
  type        = string
}

variable "lambda_runtime" {
  description = "Runtime for Lambda functions"
  type        = string
}