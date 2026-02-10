terraform {
  required_version = ">=1.1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.31.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.70.0"
    }
  }
}

#provider "aws" {
#alias  = "eu-west-2"
#region = "eu-west-2"
#}

#provider "aws" {
#alias  = "use1"
#region = "us-east-1"
#}

#provider "aws" {
#alias  = "use2"
#region = "us-east-2"
#}