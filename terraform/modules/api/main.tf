# API Gateway REST and WebSocket

resource "aws_api_gateway_rest_api" "questions" {
  name = "${var.project_name}-questions-api-${var.environment}"

  tags = {
    Name        = "${var.project_name}-questions-api"
    Environment = var.environment
  }
}

resource "aws_api_gateway_resource" "questions" {
  rest_api_id = aws_api_gateway_rest_api.questions.id
  parent_id   = aws_api_gateway_rest_api.questions.root_resource_id
  path_part   = "questions"
}

resource "aws_api_gateway_method" "get_questions" {
  rest_api_id   = aws_api_gateway_rest_api.questions.id
  resource_id   = aws_api_gateway_resource.questions.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.questions.id
  resource_id = aws_api_gateway_resource.questions.id
  http_method = aws_api_gateway_method.get_questions.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${var.lambda_get_questions_arn}/invocations"
}

resource "aws_api_gateway_deployment" "questions" {
  rest_api_id = aws_api_gateway_rest_api.questions.id

  depends_on = [
    aws_api_gateway_integration.lambda
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "questions" {
  deployment_id = aws_api_gateway_deployment.questions.id
  rest_api_id   = aws_api_gateway_rest_api.questions.id
  stage_name    = var.environment
}

########## API Gateway WebSocket API ##########
resource "aws_apigatewayv2_api" "websocket" {
  name                       = "${var.project_name}-websocket-${var.environment}"
  protocol_type             = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
  api_key_selection_expression = "$request.header.x-api-key"

  tags = {
    Name        = "${var.project_name}-websocket"
    Environment = var.environment
  }
}

resource "aws_apigatewayv2_stage" "dev" {
  api_id = aws_apigatewayv2_api.websocket.id
  name   = var.environment
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 100
    throttling_rate_limit  = 50
  }
}

# WebSocket Routes
resource "aws_apigatewayv2_route" "connect" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.websocket.id}"
}

resource "aws_apigatewayv2_route" "disconnect" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.websocket.id}"
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.websocket.id}"
}

resource "aws_apigatewayv2_route" "initiate_game" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "initiateGame"
  target    = "integrations/${aws_apigatewayv2_integration.websocket.id}"
}

resource "aws_apigatewayv2_route" "check_nickname" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "checkNickname"
  target    = "integrations/${aws_apigatewayv2_integration.websocket.id}"
}

resource "aws_apigatewayv2_route" "check_game_status" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "checkGameStatus"
  target    = "integrations/${aws_apigatewayv2_integration.websocket.id}"
}

resource "aws_apigatewayv2_route" "join_game" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "joinGame"
  target    = "integrations/${aws_apigatewayv2_integration.websocket.id}"
}

resource "aws_apigatewayv2_route" "start_game" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "startGame"
  target    = "integrations/${aws_apigatewayv2_integration.websocket.id}"
}

resource "aws_apigatewayv2_route" "next_question" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "nextQuestion"
  target    = "integrations/${aws_apigatewayv2_integration.websocket.id}"
}

resource "aws_apigatewayv2_route" "submit_answer" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "submitAnswer"
  target    = "integrations/${aws_apigatewayv2_integration.websocket.id}"
}

resource "aws_apigatewayv2_route" "end_game" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "endGame"
  target    = "integrations/${aws_apigatewayv2_integration.websocket.id}"
}

resource "aws_apigatewayv2_integration" "websocket" {
  api_id           = aws_apigatewayv2_api.websocket.id
  integration_type = "AWS_PROXY"
  integration_uri  = var.lambda_websocket_arn
  integration_method = "POST"
}

resource "aws_lambda_permission" "websocket" {
  statement_id  = "AllowWebSocketInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_websocket_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.websocket.execution_arn}/*/*"
}

resource "aws_lambda_permission" "rest_api" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_get_questions_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.questions.execution_arn}/*/*"
}