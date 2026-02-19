locals {
  region       = "eu-west-2"
  region_short = "euw2"

  # Dynamic cell mapping for different environments
  # Only state_key is needed - environment and vpc_name come from remote state
  cell_mappings = {
    # Development environment cells
    dev = {
      cell1000 = {
        state_key = "env-dev/euw2/cell1000/terraform.tfstate"
      }
      cell1001 = {
        state_key = "env-dev/euw2/cell1001/terraform.tfstate"
      }
    }
    # Production environment cells
    prod = {
      cell1000 = {
        state_key = "env-prod/euw2/cell1000/terraform.tfstate"
      }
      cell0001 = {
        state_key = "env-prod/euw2/cell0001/terraform.tfstate"
      }
    }
  }

  # Current environment from variable
  current_environment = var.target_environment

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
