locals {
  region          = "eu-west-1"
  region_short    = "euw1"
  amazon_side_asn = 64515

  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment          = "networking-tgw"
    region               = local.region
    region_short         = local.region_short
  }
}
