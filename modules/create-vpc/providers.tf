terraform {
  required_version = ">=1.1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.16.0"
      #configuration_aliases = [ aws.use1, aws.use2, aws.eu]
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