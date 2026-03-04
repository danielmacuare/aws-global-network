#module "ec2" {
  #source       = "../../../../modules/create-ec2"
  #region       = local.region
  #region_short = local.region_short
  #environment  = local.environment
  #vpc_id       = module.vpc-main.vpc.id
  #vpc_name     = local.vpc_name
  #cell_name    = local.cell_name
  #default_tags = local.default_tags

  #public_subnets  = module.vpc-main.public_subnets
  #private_subnets = module.vpc-main.private_subnets
  #key_pair_name   = data.aws_key_pair.this.key_name

  #public_security_group_id  = module.security.bastion_security_group_id
  #private_security_group_id = module.security.private_security_group_id
#}
