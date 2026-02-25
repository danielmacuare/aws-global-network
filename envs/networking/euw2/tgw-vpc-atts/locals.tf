locals {
  region       = "eu-west-2"
  region_short = "euw2"

  # Flat cell map — all environments in a single apply so every VPC
  # gets attached to the TGW and propagated to the correct route table.
  cell_mappings = {
    cell0000 = {
      state_key   = "env-prod/euw2/cell0000/terraform.tfstate"
      environment = "prod"
    }
    cell0001 = {
      state_key   = "env-prod/euw2/cell0001/terraform.tfstate"
      environment = "prod"
    }
    cell1000 = {
      state_key   = "env-dev/euw2/cell1000/terraform.tfstate"
      environment = "dev"
    }
    cell1001 = {
      state_key   = "env-dev/euw2/cell1001/terraform.tfstate"
      environment = "dev"
    }
  }

  # Supernet covering all cell CIDRs across all regions.
  # Routed into the TGW from each VPC's private subnet route tables.
  tgw_supernet_cidr = "10.0.0.0/8"

  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment          = "networking-tgw-vpc-atts"
    region               = local.region
    region_short         = local.region_short
  }
}
