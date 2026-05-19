terraform {
  required_version = ">= 1.3.0"

  # Remote state — tạo bucket và DynamoDB table trước khi chạy terraform init
  # aws s3 mb s3://shopnow-terraform-state --region ap-southeast-3
  # aws dynamodb create-table --table-name shopnow-terraform-lock \
  #   --attribute-definitions AttributeName=LockID,AttributeType=S \
  #   --key-schema AttributeName=LockID,KeyType=HASH \
  #   --billing-mode PAY_PER_REQUEST --region ap-southeast-3
  backend "s3" {
    bucket         = "shopnow-terraform-state"
    key            = "terraform.tfstate"   # override bằng -backend-config khi init
    region         = "ap-southeast-3"
    dynamodb_table = "shopnow-terraform-lock"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_region" "current" {}
