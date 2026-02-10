terraform {
  required_version = ">= 1.2.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.31.0"
    }
  }
}

provider "aws" {
  region = local.region
}