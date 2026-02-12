module "attachment_dev_vpc" {
  source = "../../../../modules/create-tgw-vpc-attachment"

  transit_gateway_id = data.terraform_remote_state.tgw.outputs.transit_gateway.id
  vpc_id             = data.terraform_remote_state.dev_vpc.outputs.vpc_id
  subnet_ids         = data.terraform_remote_state.dev_vpc.outputs.private_subnet_ids

  transit_gateway_route_table_id = data.terraform_remote_state.tgw.outputs.route_table_dev.id

  environment  = "dev"
  region_short = local.region_short
  vpc_name     = "main"
  default_tags = local.default_tags
}
