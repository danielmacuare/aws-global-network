locals {
  region        = "eu-west-2"
  aws_region    = "eu-west-2"  # Added for security module
  region_short  = "euw2"
  aws_region_short = "euw2"  # Added for security module
  environment   = "dev"
  vpc_name      = "${local.region_short}-${local.environment}"  # Dynamic naming convention
  project_root  = pathexpand("~/repos/aws-global-network")

  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment         = local.environment
    region            = local.region
    region_short      = local.region_short
  }

  private_subnets = {

    priv-0 = {
      az          = "${local.region}a"
      cidr        = "10.0.0.0/24"
      nat_gateway = true
    }

    priv-1 = {
      az          = "${local.region}b"
      cidr        = "10.0.1.0/24"
      nat_gateway = true
    }

    priv-2 = {
      az          = "${local.region}c"
      cidr        = "10.0.2.0/24"
      nat_gateway = true
    }
  }
}
