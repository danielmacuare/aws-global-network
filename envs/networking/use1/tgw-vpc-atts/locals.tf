locals {
  region       = "us-east-1"
  region_short = "use1"

  # Flat cell map — all environments in a single apply so every VPC
  # gets attached to the TGW and propagated to the correct route table.
  cell_mappings = {
    cell6000 = {
      state_key   = "env-prod/use1/cell6000/terraform.tfstate"
      environment = "prod"
    }
    cell6001 = {
      state_key   = "env-prod/use1/cell6001/terraform.tfstate"
      environment = "prod"
    }
    cell7000 = {
      state_key   = "env-dev/use1/cell7000/terraform.tfstate"
      environment = "dev"
    }
    cell7001 = {
      state_key   = "env-dev/use1/cell7001/terraform.tfstate"
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
