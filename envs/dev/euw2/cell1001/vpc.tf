module "vpc-main" {
  source = "../../../../modules/create-vpc/"

  region       = local.region
  region_short = local.region_short
  environment  = local.environment
  vpc_name     = local.vpc_name # Dynamic from locals - includes cell name
  vpc_cidr     = "10.1.16.0/20"
  default_tags = local.default_tags

  private_subnets = {

    priv-0 = {
      az          = "${local.region}a"
      cidr        = "10.1.16.0/24"
      nat_gateway = true
    }

    priv-1 = {
      az          = "${local.region}b"
      cidr        = "10.1.17.0/24"
      nat_gateway = true
    }

    priv-2 = {
      az          = "${local.region}c"
      cidr        = "10.1.18.0/24"
      nat_gateway = true
    }
  }

  public_subnets = {

    pub-0 = {
      az          = "${local.region}a"
      cidr        = "10.1.26.0/24"
      nat_gateway = false
    }

    pub-1 = {
      az          = "${local.region}b"
      cidr        = "10.1.27.0/24"
      nat_gateway = false
    }

    pub-2 = {
      az          = "${local.region}c"
      cidr        = "10.1.28.0/24"
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
  #Name       = "tgw-${var.region}"
  #active_tgw = "true"
  #})
}
