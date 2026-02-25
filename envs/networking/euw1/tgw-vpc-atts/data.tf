# Read TGW state
data "terraform_remote_state" "tgw" {
  backend = "s3"
  config = {
    bucket = var.backend_bucket
    key    = "env-networking/euw1-tgw/terraform.tfstate"
    region = "eu-west-2"
  }
}

# Dynamic VPC state data sources for each cell
data "terraform_remote_state" "vpc_states" {
  for_each = local.cell_mappings[local.current_environment]
  backend  = "s3"
  config = {
    bucket = var.backend_bucket
    key    = each.value.state_key
    region = "eu-west-2"
  }
}
