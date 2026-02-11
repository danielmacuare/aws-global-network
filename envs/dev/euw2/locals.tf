locals {
  region        = "eu-west-2"
  region_short  = "euw2"
  environment   = "dev"
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
