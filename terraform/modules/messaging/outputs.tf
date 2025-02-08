output "sqs_queue_arn" {
  value = aws_sqs_queue.game_answers.arn
}

output "sqs_queue_url" {
  value = aws_sqs_queue.game_answers.url
}