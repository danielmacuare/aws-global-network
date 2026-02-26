locals {
  region          = "us-west-2"
  region_short    = "usw2"
  amazon_side_asn = 64518

  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment          = "networking-tgw"
    region               = local.region
    region_short         = local.region_short
  }
}
