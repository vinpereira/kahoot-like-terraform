variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "github_repository_frontend" {
  type = string
}

variable "github_branch_frontend" {
  type = string
}

variable "website_bucket_id" {
  type = string
}

variable "website_bucket_arn" {
  type = string
}

variable "artifacts_bucket_id" {
  type = string
}

variable "artifacts_bucket_arn" {
  type = string
}

variable "cloudfront_distribution_id" {
  type = string
}

variable "cloudfront_distribution_arn" {
  type = string
}

variable "rest_api_url" {
  type = string
}

variable "websocket_stage_url" {
  type = string
}

variable "pipeline_notification_topic_arn" {
  description = "ARN of SNS topic for pipeline notifications"
  type        = string
  default     = ""
}

variable "notification_email" {
  description = "Email address to receive pipeline notifications"
  type        = string
}