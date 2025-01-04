provider "aws" {
  region = var.aws_region
  profile = var.aws_profile
}

provider "aws" {
  region = "us-east-1"
  profile = var.aws_profile
  alias = "us_east_1"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.2.0"
}