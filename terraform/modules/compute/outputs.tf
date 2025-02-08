output "lambda_get_questions_arn" {
  value = aws_lambda_function.get_questions.arn
}

output "lambda_get_questions_name" {
  value = aws_lambda_function.get_questions.function_name
}

output "lambda_websocket_arn" {
  value = aws_lambda_function.websocket_handler.arn
}

output "lambda_websocket_name" {
  value = aws_lambda_function.websocket_handler.function_name
}