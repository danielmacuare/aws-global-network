locals {
  region          = "eu-west-2"
  region_short    = "euw2"
  amazon_side_asn = 64514

  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment          = "networking-tgw"
    region               = local.region
    region_short         = local.region_short
  }
}
