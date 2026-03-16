terraform {
  required_version = ">= 1.14.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.31.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.70.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }
}
