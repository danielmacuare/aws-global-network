locals {
  region       = "us-west-1"
  region_short = "usw1"
  environment  = "prod"
  project_root = pathexpand("~/repos/aws-global-network")

  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment          = local.environment
    region               = local.region
    region_short         = local.region_short
  }
}
