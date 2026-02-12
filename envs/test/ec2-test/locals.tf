locals {
  region           = "eu-west-2"
  aws_region       = "eu-west-2" # Added for security module
  region_short     = "euw2"
  aws_region_short = "euw2" # Added for security module
  environment      = "ec2-test"
  vpc_name         = "${local.region_short}-${local.environment}" # Dynamic naming convention
  project_root     = pathexpand("~/repos/aws-global-network")

  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment          = local.environment
    region               = local.region
    region_short         = local.region_short
  }
}
