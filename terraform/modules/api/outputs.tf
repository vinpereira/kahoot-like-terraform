output "rest_api_url" {
  value = "${aws_api_gateway_stage.questions.invoke_url}/questions"
}

output "websocket_api_id" {
  value = aws_apigatewayv2_api.websocket.id
}

output "websocket_stage_name" {
  value = aws_apigatewayv2_stage.dev.name
}

output "websocket_stage_url" {
  value = aws_apigatewayv2_stage.dev.invoke_url
}