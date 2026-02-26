terraform {
  required_version = ">= 1.2.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.31.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.70.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }
}

provider "aws" {
  region = local.region
}

provider "awscc" {
  region = local.region
}
