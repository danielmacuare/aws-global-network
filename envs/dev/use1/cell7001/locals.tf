locals {
  region       = "us-east-1"
  region_short = "use1"
  environment  = "dev"
  cell_name    = "cell7001"
  vpc_name     = "${local.region_short}-${local.environment}-${local.cell_name}"
  project_root = pathexpand("~/repos/aws-global-network")

  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment          = local.environment
    region               = local.region
    region_short         = local.region_short
    cell_name            = local.cell_name
  }

}
