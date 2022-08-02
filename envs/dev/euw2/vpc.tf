module "vpc-main" {
  source = "../../../modules/create-vpc/"

  aws_region       = local.region
  aws_region_short = "euw2"
  environment      = "dev"
  vpc_name         = "main"
  vpc_cidr         = "10.0.0.0/20"

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

    priv-3 = {
      az          = "${local.region}c"
      cidr        = "10.0.3.0/24"
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

  #amazon_side_asn                 = var.amazon_side_asn
  #auto_accept_shared_attachments  = var.auto_accept_shared_attachments
  #default_route_table_association = var.default_route_table_association
  #default_route_table_propagation = var.default_route_table_propagation
  #description                     = local.description
  #dns_support                     = var.dns_support
  #transit_gateway_cidr_blocks     = var.transit_gateway_cidr_blocks
  #vpn_ecmp_support                = var.vpn_ecmp_support
  #tags = merge(
  #local.default_tags,
  #{
  #Name       = "tgw-${var.aws_region}"
  #active_tgw = "true"
  #})
}
