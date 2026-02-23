locals {
  region       = "eu-west-2"
  region_short = "euw2"
  environment  = "prod"
  cell_name    = "cell0001"
  vpc_name     = "${local.region_short}-${local.environment}-${local.cell_name}" # Dynamic naming convention with cell
  project_root = pathexpand("~/repos/aws-global-network")

  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment          = local.environment
    region               = local.region
    region_short         = local.region_short
    cell_name            = local.cell_name
  }

  private_subnets = {

    priv-0 = {
      az          = "${local.region}a"
      cidr        = "10.0.16.0/24"
      nat_gateway = true
    }

    priv-1 = {
      az          = "${local.region}b"
      cidr        = "10.0.17.0/24"
      nat_gateway = true
    }

    priv-2 = {
      az          = "${local.region}c"
      cidr        = "10.0.18.0/24"
      nat_gateway = true
    }
  }
}
