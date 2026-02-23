locals {
  region       = "eu-west-1"
  region_short = "euw1"
  environment  = "dev"
  project_root = pathexpand("~/repos/aws-global-network")

  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment          = local.environment
    region               = local.region
    region_short         = local.region_short
  }
}
