########## S3 Buckets and CloudFront ##########
resource "aws_s3_bucket" "website" {
  bucket = var.website_bucket_name
  force_destroy = true

  tags = {
    Name        = "${var.project_name}-website"
    Environment = var.environment
  }
}

resource "aws_s3_bucket" "artifacts" {
  bucket = var.artifacts_bucket_name
  force_destroy = true

  tags = {
    Name        = "${var.project_name}-artifacts"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "website_oac_${var.environment}"
  description                       = "Origin Access Control for website bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_cache_policy" "disabled" {
  name        = "CachingDisabled"
  comment     = "Policy with caching disabled"
  default_ttl = 0
  max_ttl     = 0
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = false
    enable_accept_encoding_gzip   = false
    
    cookies_config {
      cookie_behavior = "none"
    }
    
    headers_config {
      header_behavior = "none"
    }
    
    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.website.arn
          }
        }
      }
    ]
  })
}

resource "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name    = "AllViewerExceptHostHeader"
  comment = "Policy to forward all parameters in viewer requests except for the Host header"
  
  cookies_config {
    cookie_behavior = "all"
  }
  
  headers_config {
    header_behavior = "allExcept"
    headers {
      items = ["Host"]
    }
  }
  
  query_strings_config {
    query_string_behavior = "all"
  }
}

resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.website.bucket}"
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.website.bucket}"
    viewer_protocol_policy = "allow-all"
    # compress               = true

    cache_policy_id = aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.all_viewer_except_host.id

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "${var.project_name}-distribution"
    Environment = var.environment
  }
}
##########################################################################################

########## DynamoDB Tables ##########
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
####################################################################################################

########## SQS Queue ##########
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
####################################################################################################

########## Lambda Resource Packaging ##########
data "archive_file" "lambda_package_get_questions" {
  type = "zip"
  source_dir = "${path.module}/../lambdas/getQuestions"
  output_path = "${path.module}/../lambdas/getQuestions/getQuestions.zip"
}

data "archive_file" "lambda_package_handle_websocket" {
  type = "zip"
  source_dir = "${path.module}/../lambdas/handleWebSocket"
  output_path = "${path.module}/../lambdas/handleWebSocket/handleWebSocket.zip"
}

data "archive_file" "lambda_package_sqs_processor" {
  type = "zip"
  source_dir = "${path.module}/../lambdas/sqsProcessor"
  output_path = "${path.module}/../lambdas/sqsProcessor/sqsProcessor.zip"
}

########## Lambda Functions Configuration ##########
resource "aws_lambda_function" "get_questions" {
  filename         = data.archive_file.lambda_package_get_questions.output_path
  function_name    = "${var.project_name}-get-questions-${var.environment}"
  role            = aws_iam_role.lambda_role.arn
  handler         = "getQuestions.handler"
  runtime         = var.lambda_runtime

  tags = {
    Name        = "${var.project_name}-get-questions"
    Environment = var.environment
  }
}

resource "aws_lambda_function" "websocket_handler" {
  filename         = data.archive_file.lambda_package_handle_websocket.output_path
  function_name    = "${var.project_name}-websocket-handler-${var.environment}"
  role            = aws_iam_role.lambda_role.arn
  handler         = "handleWebSocket.handler"
  runtime         = var.lambda_runtime

  environment {
    variables = {
      WEBSOCKET_API_ENDPOINT = aws_apigatewayv2_api.websocket.api_endpoint
      SQS_QUEUE_URL         = aws_sqs_queue.game_answers.url
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
  role            = aws_iam_role.lambda_role.arn
  handler         = "sqsProcessor.handler"
  runtime         = var.lambda_runtime

  environment {
    variables = {
      WEBSOCKET_API_ENDPOINT = aws_apigatewayv2_api.websocket.api_endpoint
    }
  }

  tags = {
    Name        = "${var.project_name}-sqs-processor"
    Environment = var.environment
  }
}
##########################################################################################

########## IAM Configuration ##########
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role-${var.environment}"

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

  tags = {
    Name        = "${var.project_name}-lambda-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy-${var.environment}"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.questions.arn,
          aws_dynamodb_table.connections.arn,
          aws_dynamodb_table.games.arn,
          aws_dynamodb_table.answers.arn,
          "${aws_dynamodb_table.games.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [aws_sqs_queue.game_answers.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "execute-api:ManageConnections"
        ]
        Resource = [
          "${aws_apigatewayv2_api.websocket.execution_arn}/*",
          "${aws_api_gateway_rest_api.questions.execution_arn}/*"
        ]
      }
    ]
  })
}
##########################################################################################

########## API Gateway REST API ##########
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
  uri                    = aws_lambda_function.get_questions.invoke_arn
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
####################################################################################################

########## API Gateway WebSocket API ##########
resource "aws_apigatewayv2_api" "websocket" {
  name                       = "${var.project_name}-websocket-${var.environment}"
  protocol_type             = "WEBSOCKET"
  route_selection_expression = "$request.body.action"

  tags = {
    Name        = "${var.project_name}-websocket"
    Environment = var.environment
  }
}

resource "aws_apigatewayv2_stage" "dev" {
  api_id = aws_apigatewayv2_api.websocket.id
  name   = var.environment
  auto_deploy = true
}

# WebSocket Routes
## Default routes
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
## Game-specific routes
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

# WebSocket Integration (shared by all routes)
resource "aws_apigatewayv2_integration" "websocket" {
  api_id           = aws_apigatewayv2_api.websocket.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.websocket_handler.invoke_arn
  integration_method = "POST"
}
##########################################################################################

########## Lambda permissions ##########
resource "aws_lambda_permission" "websocket" {
  statement_id  = "AllowWebSocketInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.websocket_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.websocket.execution_arn}/*/*"
}

resource "aws_lambda_permission" "rest_api" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_questions.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.questions.execution_arn}/*/*"
}

########## SQS Event Source Mapping ##########
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.game_answers.arn
  function_name    = aws_lambda_function.sqs_processor.arn
  batch_size       = 1
}

########## GitHub Connection for Frontend ##########
resource "aws_codestarconnections_connection" "github" {
  name          = "${var.project_name}-github-${var.environment}"
  provider_type = "GitHub"

  tags = {
    Name        = "${var.project_name}-github-connection"
    Environment = var.environment
  }
}

########## CodeBuild Role and Policy ##########
resource "aws_iam_role" "codebuild_role" {
  name = "${var.project_name}-codebuild-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-codebuild-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "${var.project_name}-codebuild-policy-${var.environment}"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*",
          aws_s3_bucket.website.arn,
          "${aws_s3_bucket.website.arn}/*"
        ]
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
      },
      {
        Effect = "Allow"
        Resource = ["*"]
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
      },
      {
        Effect = "Allow"
        Resource = [ aws_cloudfront_distribution.website.arn ]
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListInvalidations"
        ]
      }
    ]
  })
}

########## CodeBuild Project ##########
resource "aws_codebuild_project" "frontend" {
  name          = "${var.project_name}-frontend-${var.environment}"
  description   = "Build React frontend application"
  build_timeout = "15"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                      = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "REACT_APP_API_ENDPOINT"
      value = "${aws_api_gateway_stage.questions.invoke_url}/questions"
    }

    environment_variable {
      name  = "REACT_APP_WS_ENDPOINT"
      value = aws_apigatewayv2_stage.dev.invoke_url
    }

    environment_variable {
      name  = "WEBSITE_BUCKET"
      value = aws_s3_bucket.website.id
    }

    environment_variable {
      name  = "CLOUDFRONT_DISTRIBUTION_ID"
      value = aws_cloudfront_distribution.website.id
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project_name}-frontend-${var.environment}"
      stream_name = "build-logs"
    }
  }

  tags = {
    Name        = "${var.project_name}-frontend-build"
    Environment = var.environment
  }
}

########## CodePipeline Role ##########
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.project_name}-codepipeline-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-codepipeline-role"
    Environment = var.environment
  }
}

########## CodePipeline Policy ##########
resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${var.project_name}-codepipeline-policy-${var.environment}"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*",
          aws_s3_bucket.website.arn,
          "${aws_s3_bucket.website.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = [aws_codebuild_project.frontend.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
        Resource = [aws_codestarconnections_connection.github.arn]
      }
    ]
  })
}

########## CodePipeline ##########
resource "aws_codepipeline" "frontend" {
  name     = "${var.project_name}-frontend-pipeline-${var.environment}"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = var.github_repository_frontend
        BranchName       = var.github_branch_frontend
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner          = "AWS"
      provider       = "CodeBuild"
      input_artifacts = ["source_output"]
      version        = "1"

      configuration = {
        ProjectName = aws_codebuild_project.frontend.name
      }
    }
  }

  tags = {
    Name        = "${var.project_name}-frontend-pipeline"
    Environment = var.environment
  }
}