module "security" {
  source       = "../../../../modules/security"
  vpc_id       = module.vpc-main.vpc.id
  vpc_cidr     = module.vpc-main.vpc.cidr_block
  region_short = local.region_short
  environment  = local.environment
  cell_name    = local.cell_name
  default_tags = local.default_tags

  public_subnet_ids  = [for k, v in module.vpc-main.public_subnets : v.id]
  private_subnet_ids = [for k, v in module.vpc-main.private_subnets : v.id]

  env_supernet_cidr = "10.48.0.0/16"

  cross_region_supernet_cidrs = [
    "10.0.0.0/16",  # euw2-prod
    "10.16.0.0/16", # euw1-prod
    "10.32.0.0/16", # usw2-prod
  ]
}
