# Lambda functions and roles

data "archive_file" "lambda_package_get_questions" {
  type = "zip"
  source_dir  = "${path.module}/../../lambdas/getQuestions"
  output_path = "${path.module}/../../${var.lambda_artifacts_dir}/getQuestions.zip"
}

data "archive_file" "lambda_package_handle_websocket" {
  type = "zip"
  source_dir  = "${path.module}/../../lambdas/handleWebSocket"
  output_path = "${path.module}/../../${var.lambda_artifacts_dir}/handleWebSocket.zip"
}

data "archive_file" "lambda_package_sqs_processor" {
  type = "zip"
  source_dir  = "${path.module}/../../lambdas/sqsProcessor"
  output_path = "${path.module}/../../${var.lambda_artifacts_dir}/sqsProcessor.zip"
}

resource "aws_lambda_function" "get_questions" {
  filename         = data.archive_file.lambda_package_get_questions.output_path
  function_name    = "${var.project_name}-get-questions-${var.environment}"
  role            = aws_iam_role.get_questions_lambda_role.arn
  handler         = "getQuestions.handler"
  runtime         = var.lambda_runtime
  source_code_hash = data.archive_file.lambda_package_get_questions.output_base64sha256

  tags = {
    Name        = "${var.project_name}-get-questions"
    Environment = var.environment
  }
}

resource "aws_lambda_function" "websocket_handler" {
  filename         = data.archive_file.lambda_package_handle_websocket.output_path
  function_name    = "${var.project_name}-websocket-handler-${var.environment}"
  role            = aws_iam_role.websocket_lambda_role.arn
  handler         = "handleWebSocket.handler"
  runtime         = var.lambda_runtime
  source_code_hash = data.archive_file.lambda_package_handle_websocket.output_base64sha256

  environment {
    variables = {
      WEBSOCKET_API_ENDPOINT = replace(var.websocket_stage_url, "wss://", "https://")
      SQS_QUEUE_URL         = var.sqs_queue_url
    }
  }

  tags = {
    Name        = "${var.project_name}-websocket-handler"
    Environment = var.environment
  }
}

resource "aws_lambda_function" "sqs_processor" {
  filename         = data.archive_file.lambda_package_sqs_processor.output_path
  function_name    = "${var.project_name}-sqs-processor-${var.environment}"
  role            = aws_iam_role.sqs_processor_lambda_role.arn
  handler         = "sqsProcessor.handler"
  runtime         = var.lambda_runtime
  source_code_hash = data.archive_file.lambda_package_sqs_processor.output_base64sha256

  environment {
    variables = {
      WEBSOCKET_API_ENDPOINT = replace(var.websocket_stage_url, "wss://", "https://")
    }
  }

  tags = {
    Name        = "${var.project_name}-sqs-processor"
    Environment = var.environment
  }
}

resource "aws_iam_role" "get_questions_lambda_role" {
  name = "${var.project_name}-get-questions-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "get_questions_lambda_policy" {
  name = "${var.project_name}-get-questions-lambda-policy-${var.environment}"
  role = aws_iam_role.get_questions_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "logs:CreateLogGroup"
        Resource = "arn:aws:logs:${var.aws_region}:${var.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/lambda/${var.project_name}-get-questions-${var.environment}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["dynamodb:Scan"]
        Resource = [var.questions_table_arn]
      }
    ]
  })
}

resource "aws_iam_role" "websocket_lambda_role" {
  name = "${var.project_name}-websocket-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "websocket_lambda_policy" {
  name = "${var.project_name}-websocket-lambda-policy-${var.environment}"
  role = aws_iam_role.websocket_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "logs:CreateLogGroup"
        Resource = "arn:aws:logs:${var.aws_region}:${var.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/lambda/${var.project_name}-websocket-handler-${var.environment}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:DeleteItem",
          "dynamodb:PutItem"
        ]
        Resource = [var.connections_table_arn]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Resource = [var.games_table_arn]
      },
      {
        Effect = "Allow"
        Action = ["dynamodb:Query"]
        Resource = ["${var.games_table_arn}/index/GameCodeIndex"]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Scan"
        ]
        Resource = [var.questions_table_arn]
      },
      {
        Effect = "Allow"
        Action = ["sqs:SendMessage"]
        Resource = [var.sqs_queue_arn]
      },
      {
        Effect = "Allow"
        Action = ["execute-api:ManageConnections"]
        Resource = [
          "arn:aws:execute-api:${var.aws_region}:${var.account_id}:${var.websocket_api_id}/${var.websocket_stage_name}/POST/@connections/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "sqs_processor_lambda_role" {
  name = "${var.project_name}-sqs-processor-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "sqs_processor_lambda_policy" {
  name = "${var.project_name}-sqs-processor-lambda-policy-${var.environment}"
  role = aws_iam_role.sqs_processor_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "logs:CreateLogGroup"
        Resource = "arn:aws:logs:${var.aws_region}:${var.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/lambda/${var.project_name}-sqs-processor-${var.environment}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["dynamodb:GetItem"]
        Resource = [var.questions_table_arn]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Resource = [var.games_table_arn]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:Scan"
        ]
        Resource = [var.answers_table_arn]
      },
      {
        Effect = "Allow"
        Action = ["execute-api:ManageConnections"]
        Resource = [
          "arn:aws:execute-api:${var.aws_region}:${var.account_id}:${var.websocket_api_id}/${var.websocket_stage_name}/POST/@connections/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [var.sqs_queue_arn]
      }
    ]
  })
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = var.sqs_queue_arn
  function_name    = aws_lambda_function.sqs_processor.arn
  batch_size       = 1

  depends_on = [
    aws_iam_role_policy.sqs_processor_lambda_policy
  ]
}