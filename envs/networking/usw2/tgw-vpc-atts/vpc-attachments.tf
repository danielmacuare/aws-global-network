module "vpc_attachments" {
  for_each = local.cell_mappings
  source   = "../../../../modules/create-tgw-vpc-attachment"

  transit_gateway_id = data.terraform_remote_state.tgw.outputs.transit_gateway.id
  vpc_id             = data.terraform_remote_state.vpc_states[each.key].outputs.vpc.id
  subnet_ids         = data.terraform_remote_state.vpc_states[each.key].outputs.private_subnet_ids

  transit_gateway_route_table_id = (
    each.value.environment == "prod"
    ? data.terraform_remote_state.tgw.outputs.route_table_prod.id
    : data.terraform_remote_state.tgw.outputs.route_table_dev.id
  )
  transit_gateway_wan_route_table_id = data.terraform_remote_state.tgw.outputs.route_table_wan.id

  environment  = each.value.environment
  region_short = local.region_short
  vpc_name     = try(data.terraform_remote_state.vpc_states[each.key].outputs.vpc.name, "main")

  private_route_table_ids = data.terraform_remote_state.vpc_states[each.key].outputs.private_route_tables_id
  tgw_supernet_cidr       = local.tgw_supernet_cidr

  default_tags = merge(local.default_tags, {
    cell = each.key
  })
}
