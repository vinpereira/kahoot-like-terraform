# DynamoDB tables

resource "aws_dynamodb_table" "questions" {
  name           = "KahootQuestions"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "QuestionID"
  
  attribute {
    name = "QuestionID"
    type = "S"
  }

  tags = {
    Name        = "${var.project_name}-questions"
    Environment = var.environment
  }
}

resource "aws_dynamodb_table" "connections" {
  name           = "KahootConnections"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "connectionId"
  
  attribute {
    name = "connectionId"
    type = "S"
  }

  tags = {
    Name        = "${var.project_name}-connections"
    Environment = var.environment
  }
}

resource "aws_dynamodb_table" "games" {
  name           = "KahootGames"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "gameId"
  
  attribute {
    name = "gameId"
    type = "S"
  }
  
  attribute {
    name = "gameCode"
    type = "S"
  }

  global_secondary_index {
    name               = "GameCodeIndex"
    hash_key           = "gameCode"
    projection_type    = "ALL"
  }

  tags = {
    Name        = "${var.project_name}-games"
    Environment = var.environment
  }
}

resource "aws_dynamodb_table" "answers" {
  name           = "KahootAnswers"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "gameId_playerId"
  range_key      = "questionId"
  
  attribute {
    name = "gameId_playerId"
    type = "S"
  }
  
  attribute {
    name = "questionId"
    type = "S"
  }

  tags = {
    Name        = "${var.project_name}-answers"
    Environment = var.environment
  }
}