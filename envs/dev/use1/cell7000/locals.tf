locals {
  region       = "us-east-1"
  region_short = "use1"
  environment  = "dev"
  cell_name    = "cell7000"
  vpc_name     = "${local.region_short}-${local.environment}-${local.cell_name}"
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
      cidr        = "10.49.0.0/24"
      nat_gateway = true
    }
    priv-1 = {
      az          = "${local.region}b"
      cidr        = "10.49.1.0/24"
      nat_gateway = true
    }
    priv-2 = {
      az          = "${local.region}c"
      cidr        = "10.49.2.0/24"
      nat_gateway = true
    }
  }
}
