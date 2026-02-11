module "ec2" {
  source           = "../../../modules/create-ec2"
  aws_region       = local.region
  aws_region_short = local.region_short
  environment      = local.environment
  vpc_id           = module.vpc-main.vpc.id
  vpc_name         = local.vpc_name  # Dynamic from locals
  default_tags     = local.default_tags

  public_subnets  = module.vpc-main.public_subnets
  private_subnets = module.vpc-main.private_subnets
  key_pair_name   = module.key_pair.key_pair_name

  # Using custom security groups from security module
  public_security_group_id  = module.security.bastion_security_group_id
  private_security_group_id = module.security.private_security_group_id
}
