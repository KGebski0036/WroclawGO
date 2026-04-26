terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "s3" {
  source             = "./modules/s3"
  bucket_name        = "${var.project_name}-frontend-${var.environment}"
  log_retention_days = var.log_retention_days
}
