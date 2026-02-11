module "ec2" {
  source           = "../../../modules/create-ec2"
  aws_region       = local.region
  aws_region_short = local.region_short
  environment      = local.environment
  vpc_id           = module.vpc-main.vpc.id
  vpc_name         = "main"
  default_tags     = local.default_tags

  public_subnets  = module.vpc-main.public_subnets
  private_subnets = module.vpc-main.private_subnets
  key_pair_name   = module.key_pair.key_pair_name

  # Using VPC default security groups (Phase 5 will add custom SGs)
}
