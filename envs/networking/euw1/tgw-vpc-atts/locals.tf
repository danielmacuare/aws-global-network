locals {
  region       = "eu-west-1"
  region_short = "euw1"

  # Flat cell map — all environments in a single apply so every VPC
  # gets attached to the TGW and propagated to the correct route table.
  cell_mappings = {
    cell2000 = {
      state_key   = "env-prod/euw1/cell2000/terraform.tfstate"
      environment = "prod"
    }
    cell2001 = {
      state_key   = "env-prod/euw1/cell2001/terraform.tfstate"
      environment = "prod"
    }
    cell3000 = {
      state_key   = "env-dev/euw1/cell3000/terraform.tfstate"
      environment = "dev"
    }
    cell3001 = {
      state_key   = "env-dev/euw1/cell3001/terraform.tfstate"
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
