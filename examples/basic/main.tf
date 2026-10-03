terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.83"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

provider "aws" {
  alias  = "us_east"
  region = "us-east-1"
}

variable "distribution_arn" {
  description = "ARN of an existing CloudFront distribution"
  type        = string
}

module "edge_logging" {
  source = "../.."

  providers = {
    aws.us_east = aws.us_east
  }

  name = "example"
  distribution_arns = {
    site = var.distribution_arn
  }
}

output "bucket" {
  value = module.edge_logging.bucket
}
