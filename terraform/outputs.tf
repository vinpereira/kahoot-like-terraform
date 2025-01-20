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

output "websocket_api_endpoint" {
  description = "Raw WebSocket API endpoint"
  value       = aws_apigatewayv2_api.websocket.api_endpoint
}

output "websocket_stage_invoke_url" {
  description = "WebSocket stage invoke URL"
  value       = aws_apigatewayv2_stage.dev.invoke_url
}

output "lambda_websocket_endpoint" {
  description = "WebSocket endpoint used in Lambda"
  value       = "${aws_apigatewayv2_api.websocket.api_endpoint}/${aws_apigatewayv2_stage.dev.name}"
}