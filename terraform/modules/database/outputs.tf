output "questions_table_arn" {
  value = aws_dynamodb_table.questions.arn
}

output "connections_table_arn" {
  value = aws_dynamodb_table.connections.arn
}

output "games_table_arn" {
  value = aws_dynamodb_table.games.arn
}

output "answers_table_arn" {
  value = aws_dynamodb_table.answers.arn
}