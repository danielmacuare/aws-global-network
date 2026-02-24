module "vpc-main" {
  source = "../../../../modules/create-vpc/"

  region       = local.region
  region_short = local.region_short
  environment  = local.environment
  vpc_name     = local.vpc_name # Dynamic from locals - includes cell name
  cell_name    = local.cell_name
  vpc_cidr     = "10.0.0.0/20"
  default_tags = local.default_tags

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

  public_subnets = {

    pub-0 = {
      az          = "${local.region}a"
      cidr        = "10.0.10.0/24"
      nat_gateway = false
    }

    pub-1 = {
      az          = "${local.region}b"
      cidr        = "10.0.11.0/24"
      nat_gateway = false
    }

    pub-2 = {
      az          = "${local.region}c"
      cidr        = "10.0.12.0/24"
      nat_gateway = false
    }

  }

  # Optional
  assign_generated_ipv6_cidr_block = "true"
}
