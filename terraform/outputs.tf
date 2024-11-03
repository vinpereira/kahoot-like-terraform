output "cloudfront_domain" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.website.domain_name
}

output "rest_api_url" {
  description = "URL of the REST API"
  value       = "${aws_api_gateway_stage.questions.invoke_url}/questions"
}

output "websocket_url" {
  description = "URL of the WebSocket API"
  value       = aws_apigatewayv2_stage.dev.invoke_url
}

output "artifacts_bucket" {
  description = "Name of the artifacts S3 bucket"
  value       = aws_s3_bucket.artifacts.bucket
}

output "website_bucket" {
  description = "Name of the website S3 bucket"
  value       = aws_s3_bucket.website.bucket
}

output "github_connection_arn" {
  description = "ARN of the GitHub connection"
  value       = aws_codestarconnections_connection.github.arn
}