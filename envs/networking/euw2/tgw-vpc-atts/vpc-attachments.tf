# Dynamic VPC attachments for all cells in current environment
module "vpc_attachments" {
  for_each = local.cell_mappings[local.current_environment]
  source   = "../../../../modules/create-tgw-vpc-attachment"

  transit_gateway_id = data.terraform_remote_state.tgw.outputs.transit_gateway.id
  vpc_id             = data.terraform_remote_state.vpc_states[each.key].outputs.vpc.id
  subnet_ids         = data.terraform_remote_state.vpc_states[each.key].outputs.private_subnet_ids

  # ✅ DYNAMIC route table assignment based on VPC environment
  # Dev VPCs → dev route table, Prod VPCs → prod route table
  transit_gateway_route_table_id = try(
    data.terraform_remote_state.vpc_states[each.key].outputs.vpc.environment == "prod" ?
    data.terraform_remote_state.tgw.outputs.route_table_prod.id :
    data.terraform_remote_state.tgw.outputs.route_table_dev.id,
    data.terraform_remote_state.tgw.outputs.route_table_dev.id # Fallback to dev
  )

  # ✅ DYNAMIC with fallback - Use remote state when available, hardcoded when not
  environment  = try(data.terraform_remote_state.vpc_states[each.key].outputs.vpc.environment, "dev")
  region_short = local.region_short
  vpc_name     = try(data.terraform_remote_state.vpc_states[each.key].outputs.vpc.name, "main")

  private_route_table_ids = data.terraform_remote_state.vpc_states[each.key].outputs.private_route_tables_id
  tgw_supernet_cidr       = local.tgw_supernet_cidr

  default_tags = merge(local.default_tags, {
    cell = each.key
  })
}
