module "security" {
  source       = "../../../../modules/security"
  vpc_id       = module.vpc-main.vpc.id
  vpc_cidr     = module.vpc-main.vpc.cidr_block # From VPC module output
  region_short = local.region_short
  environment  = local.environment
  cell_name    = local.cell_name
  default_tags = local.default_tags

  public_subnet_ids  = [for k, v in module.vpc-main.public_subnets : v.id]
  private_subnet_ids = [for k, v in module.vpc-main.private_subnets : v.id]

  # Allow all dev euw2 cells (10.1.0.0/16) to communicate via TGW
  env_supernet_cidr = "10.1.0.0/16"

  # Allow dev euw1 cells (10.17.0.0/16) via cross-region TGW peering
  cross_region_supernet_cidr = "10.17.0.0/16"
}
