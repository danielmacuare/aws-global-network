locals {
  region       = "eu-west-2"
  region_short = "euw2"
  environment  = "test"
  project_root = pathexpand("~/repos/aws-global-network")

  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment          = local.environment
    region               = local.region
    region_short         = local.region_short
  }
}
