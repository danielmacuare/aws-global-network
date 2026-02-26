module "vpc-main" {
  source = "../../../../modules/create-vpc/"

  region       = local.region
  region_short = local.region_short
  environment  = local.environment
  vpc_name     = local.vpc_name
  cell_name    = local.cell_name
  vpc_cidr     = "10.49.16.0/20"
  default_tags = local.default_tags

  private_subnets = {
    priv-0 = {
      az          = "${local.region}a"
      cidr        = "10.49.16.0/24"
      nat_gateway = true
    }
    priv-1 = {
      az          = "${local.region}b"
      cidr        = "10.49.17.0/24"
      nat_gateway = true
    }
  }

  public_subnets = {
    pub-0 = {
      az          = "${local.region}a"
      cidr        = "10.49.26.0/24"
      nat_gateway = false
    }
    pub-1 = {
      az          = "${local.region}b"
      cidr        = "10.49.27.0/24"
      nat_gateway = false
    }
  }

  assign_generated_ipv6_cidr_block = "true"
}
