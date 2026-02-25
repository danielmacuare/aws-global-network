terraform {
  required_version = ">= 1.2.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.31.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }
}

# Default provider — eu-west-2 (requester region)
provider "aws" {
  region = "eu-west-2"
}

# Aliased provider — eu-west-1 (accepter region)
provider "aws" {
  alias  = "euw1"
  region = "eu-west-1"
}
