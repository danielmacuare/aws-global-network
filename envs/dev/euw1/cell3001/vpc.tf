module "vpc-main" {
  source = "../../../../modules/create-vpc/"

  region_short = local.region_short
  environment  = local.environment
  vpc_name     = local.vpc_name
  cell_name    = local.cell_name
  vpc_cidr     = "10.17.16.0/20"
  default_tags = local.default_tags

  private_subnets = {
    priv-0 = {
      az          = "${local.region}a"
      cidr        = "10.17.16.0/24"
      nat_gateway = true
    }
    priv-1 = {
      az          = "${local.region}b"
      cidr        = "10.17.17.0/24"
      nat_gateway = true
    }
    priv-2 = {
      az          = "${local.region}c"
      cidr        = "10.17.18.0/24"
      nat_gateway = true
    }
  }

  public_subnets = {
    pub-0 = {
      az          = "${local.region}a"
      cidr        = "10.17.26.0/24"
      nat_gateway = false
    }
    pub-1 = {
      az          = "${local.region}b"
      cidr        = "10.17.27.0/24"
      nat_gateway = false
    }
    pub-2 = {
      az          = "${local.region}c"
      cidr        = "10.17.28.0/24"
      nat_gateway = false
    }
  }

  assign_generated_ipv6_cidr_block = "true"
}
