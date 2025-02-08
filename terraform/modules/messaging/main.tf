# SQS Queue

resource "aws_sqs_queue" "game_answers" {
  name                      = "${var.project_name}-game-answers-${var.environment}"
  visibility_timeout_seconds = 30
  message_retention_seconds = 1209600
  receive_wait_time_seconds = 20

  tags = {
    Name        = "${var.project_name}-game-answers"
    Environment = var.environment
  }
}