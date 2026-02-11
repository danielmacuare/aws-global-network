locals {
  region       = "eu-west-2"
  region_short = "euw2"
  environment  = "test"
  project_root = pathexpand("~/repos/aws-global-network")

  default_tags = {
    Environment = "test"
    ManagedBy   = "terraform"
    Project     = "aws-global-network"
  }
}
