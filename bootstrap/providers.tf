terraform {
  required_version = ">= 1.14.4"

  required_providers {
    # AWS Common Commands - https://registry.terraform.io/providers/hashicorp/awscc/latest/docs
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.16.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 0.25.0"
    }
  }
}

provider "aws" {
  region = local.region
}
