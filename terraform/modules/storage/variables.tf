variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev/prod)"
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