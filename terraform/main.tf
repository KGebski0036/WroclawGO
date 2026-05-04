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

  backend "s3" {
    # Bucket name, key, and region are passed via -backend-config flags at `terraform init` time,
    # or via TF_CLI_ARGS_init env var in CI. This keeps the config portable across environments.
    # Required -backend-config values:
    #   bucket  = "<TF_STATE_BUCKET>"          e.g. wroclawgo-terraform-state
    #   key     = "wroclawgo/terraform.tfstate"
    #   region  = "<AWS_REGION>"               e.g. eu-central-1
    #   dynamodb_table = "wroclawgo-terraform-locks"
    #   encrypt = true
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
