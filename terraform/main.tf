data "aws_caller_identity" "current" {}

module "storage" {
  source = "./modules/storage"
  project_name = var.project_name
  environment = var.environment
  website_bucket_name = var.website_bucket_name
  artifacts_bucket_name = var.artifacts_bucket_name
}

module "database" {
  source = "./modules/database"
  project_name = var.project_name
  environment = var.environment
}

module "messaging" {
  source = "./modules/messaging"
  project_name = var.project_name
  environment = var.environment
}

module "compute" {
  source = "./modules/compute"
  project_name = var.project_name
  environment = var.environment
  aws_region = var.aws_region
  lambda_runtime = var.lambda_runtime
  account_id = data.aws_caller_identity.current.account_id
  lambda_artifacts_dir = "lambda_artifacts"
  websocket_api_id = module.api.websocket_api_id
  websocket_stage_name = module.api.websocket_stage_name
  questions_table_arn = module.database.questions_table_arn
  connections_table_arn = module.database.connections_table_arn
  games_table_arn = module.database.games_table_arn
  answers_table_arn = module.database.answers_table_arn
  sqs_queue_arn = module.messaging.sqs_queue_arn
  sqs_queue_url = module.messaging.sqs_queue_url
  websocket_stage_url = module.api.websocket_stage_url
}

module "api" {
  source = "./modules/api"
  aws_region = var.aws_region
  project_name = var.project_name
  environment = var.environment
  lambda_get_questions_arn = module.compute.lambda_get_questions_arn
  lambda_get_questions_name = module.compute.lambda_get_questions_name
  lambda_websocket_arn = module.compute.lambda_websocket_arn
  lambda_websocket_name = module.compute.lambda_websocket_name
}

module "ci_cd" {
  source = "./modules/ci_cd"
  project_name = var.project_name
  environment = var.environment
  github_repository_frontend = var.github_repository_frontend
  github_branch_frontend = var.github_branch_frontend
  website_bucket_id = module.storage.website_bucket_id
  website_bucket_arn = module.storage.website_bucket_arn
  artifacts_bucket_id = module.storage.artifacts_bucket_id
  artifacts_bucket_arn = module.storage.artifacts_bucket_arn
  cloudfront_distribution_id = module.storage.cloudfront_distribution_id
  cloudfront_distribution_arn = module.storage.cloudfront_distribution_arn
  rest_api_url = module.api.rest_api_url
  websocket_stage_url = module.api.websocket_stage_url
  notification_email = var.notification_email
}