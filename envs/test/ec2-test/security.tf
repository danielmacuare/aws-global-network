module "security" {
  source           = "../../../modules/security"
  vpc_id           = module.test_vpc.vpc.id
  vpc_cidr         = module.test_vpc.vpc.cidr_block  # From VPC module output
  aws_region_short = local.region_short
  environment      = local.environment
  default_tags     = local.default_tags
  
  public_subnet_ids  = [for k, v in module.test_vpc.public_subnets : v.id]
  private_subnet_ids = [for k, v in module.test_vpc.private_subnets : v.id]
}
