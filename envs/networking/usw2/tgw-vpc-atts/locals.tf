locals {
  region       = "us-west-2"
  region_short = "usw2"

  # Flat cell map — all environments in a single apply so every VPC
  # gets attached to the TGW and propagated to the correct route table.
  cell_mappings = {
    cell4000 = {
      state_key   = "env-prod/usw2/cell4000/terraform.tfstate"
      environment = "prod"
    }
    cell4001 = {
      state_key   = "env-prod/usw2/cell4001/terraform.tfstate"
      environment = "prod"
    }
    cell5000 = {
      state_key   = "env-dev/usw2/cell5000/terraform.tfstate"
      environment = "dev"
    }
    cell5001 = {
      state_key   = "env-dev/usw2/cell5001/terraform.tfstate"
      environment = "dev"
    }
  }

  tgw_supernet_cidr = "10.0.0.0/8"

  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment          = "networking-tgw-vpc-atts"
    region               = local.region
    region_short         = local.region_short
  }
}
