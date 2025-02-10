data "aws_caller_identity" "current" {}

resource "aws_codestarconnections_connection" "github" {
  name          = "${var.project_name}-github-${var.environment}"
  provider_type = "GitHub"

  tags = {
    Name        = "${var.project_name}-github-connection"
    Environment = var.environment
  }
}

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
          var.artifacts_bucket_arn,
          "${var.artifacts_bucket_arn}/*",
          var.website_bucket_arn,
          "${var.website_bucket_arn}/*"
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
        Resource = [var.cloudfront_distribution_arn]
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListInvalidations"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:DescribeKey"
        ]
        Resource = [aws_kms_key.artifact_encryption_key.arn]
      }
    ]
  })
}

resource "aws_codebuild_project" "frontend" {
  name          = "${var.project_name}-frontend-${var.environment}"
  description   = "Build React frontend application"
  build_timeout = "15"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
    encryption_disabled = false
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                      = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode            = true

    environment_variable {
      name  = "REACT_APP_API_ENDPOINT"
      value = var.rest_api_url
    }

    environment_variable {
      name  = "REACT_APP_WS_ENDPOINT"
      value = var.websocket_stage_url
    }

    environment_variable {
      name  = "WEBSITE_BUCKET"
      value = var.website_bucket_id
    }

    environment_variable {
      name  = "CLOUDFRONT_DISTRIBUTION_ID"
      value = var.cloudfront_distribution_id
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
      status      = "ENABLED"
    }
  }

  tags = {
    Name        = "${var.project_name}-frontend-build"
    Environment = var.environment
  }
}

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
}

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
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.artifacts_bucket_arn,
          "${var.artifacts_bucket_arn}/*",
          var.website_bucket_arn,
          "${var.website_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
          "codebuild:BatchGetBuildBatches",
          "codebuild:StartBuildBatch"
        ]
        Resource = [aws_codebuild_project.frontend.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
        Resource = [aws_codestarconnections_connection.github.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:DescribeKey"
        ]
        Resource = [aws_kms_key.artifact_encryption_key.arn]
      }
    ]
  })
}

# KMS key for artifact encryption
resource "aws_kms_key" "artifact_encryption_key" {
  description             = "KMS key for CodePipeline artifacts"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-artifact-encryption"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "artifact_encryption_key" {
  name          = "alias/${var.project_name}-${var.environment}-artifacts"
  target_key_id = aws_kms_key.artifact_encryption_key.key_id
}

resource "aws_kms_key_policy" "artifact_encryption_key" {
  key_id = aws_kms_key.artifact_encryption_key.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CodePipeline to use the key"
        Effect = "Allow"
        Principal = {
          AWS = [
            aws_iam_role.codepipeline_role.arn,
            aws_iam_role.codebuild_role.arn
          ]
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_codepipeline" "frontend" {
  name     = "${var.project_name}-frontend-v2-pipeline-${var.environment}"
  role_arn = aws_iam_role.codepipeline_role.arn
  pipeline_type = "V2"

  artifact_store {
    location = var.artifacts_bucket_id
    type     = "S3"
    encryption_key {
      id   = aws_kms_key.artifact_encryption_key.arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner           = "AWS"
      provider        = "CodeStarSourceConnection"
      version         = "1"
      output_artifacts = ["source_output"]
      namespace       = "SourceVariables"
      
      configuration = {
        ConnectionArn           = aws_codestarconnections_connection.github.arn
        FullRepositoryId       = var.github_repository_frontend
        BranchName            = var.github_branch_frontend
        DetectChanges         = true
        OutputArtifactFormat  = "CODE_ZIP"
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
      namespace      = "BuildVariables"
      
      configuration = {
        ProjectName = aws_codebuild_project.frontend.name
        BatchEnabled = false
        PrimarySource = "source_output"
      }
    }
  }

  trigger {
    provider_type = "CodeStarSourceConnection"
    
    git_configuration {
      source_action_name = "Source"
      
      push {
        branches {
          includes = [var.github_branch_frontend]
        }
        file_paths { 
          includes = ["*"]
        }
      }
    }
  }
}

resource "aws_sns_topic" "pipeline_notifications" {
  name = "${var.project_name}-pipeline-notifications-${var.environment}"

  tags = {
    Name        = "${var.project_name}-pipeline-notifications"
    Environment = var.environment
  }
}

resource "aws_sns_topic_policy" "pipeline_notifications" {
  arn = aws_sns_topic.pipeline_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchEvents"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.pipeline_notifications.arn
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "pipeline_notifications_email" {
  topic_arn = aws_sns_topic.pipeline_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_cloudwatch_event_rule" "pipeline_state_change" {
  name        = "${var.project_name}-pipeline-state-change-${var.environment}"
  description = "Monitor CodePipeline state changes"

  event_pattern = jsonencode({
    source      = ["aws.codepipeline"]
    detail-type = ["CodePipeline Pipeline Execution State Change"]
    detail = {
      pipeline = [aws_codepipeline.frontend.name]
    }
  })
}

resource "aws_cloudwatch_event_target" "pipeline_state_change" {
  rule      = aws_cloudwatch_event_rule.pipeline_state_change.id
  target_id = "CodePipelineStateChange"
  arn       = aws_sns_topic.pipeline_notifications.arn

  depends_on = [
    aws_sns_topic.pipeline_notifications,
    aws_sns_topic_policy.pipeline_notifications,
    aws_cloudwatch_event_rule.pipeline_state_change
  ]
  
  input_transformer {
    input_paths = {
      pipeline = "$.detail.pipeline"
      state    = "$.detail.state"
      execution_id = "$.detail.execution-id"
    }
    input_template = "\"Pipeline '<pipeline>' (Execution ID: <execution_id>) entered state: <state>\""
  }
}