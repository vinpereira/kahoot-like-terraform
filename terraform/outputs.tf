output "cloudfront_domain" {
  description = "CloudFront distribution domain name"
  value       = module.storage.cloudfront_domain
}

output "api_url" {
  description = "URL of the REST API"
  value       = module.api.rest_api_url
}

output "websocket_url" {
  description = "WebSocket stage invoke URL"
  value       = module.api.websocket_stage_url
}

output "github_connection_arn" {
  description = "ARN of the GitHub connection"
  value       = module.ci_cd.github_connection_arn
}