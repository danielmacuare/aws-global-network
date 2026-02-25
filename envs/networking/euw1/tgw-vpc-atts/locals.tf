locals {
  region       = "eu-west-1"
  region_short = "euw1"

  cell_mappings = {
    dev = {
      cell3000 = {
        state_key = "env-dev/euw1/cell3000/terraform.tfstate"
      }
      cell3001 = {
        state_key = "env-dev/euw1/cell3001/terraform.tfstate"
      }
    }
    prod = {
      cell2000 = {
        state_key = "env-prod/euw1/cell2000/terraform.tfstate"
      }
      cell2001 = {
        state_key = "env-prod/euw1/cell2001/terraform.tfstate"
      }
    }
  }

  current_environment = var.target_environment
  tgw_supernet_cidr   = "10.0.0.0/8"

  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment          = "networking-tgw-vpc-atts"
    region               = local.region
    region_short         = local.region_short
  }
}
