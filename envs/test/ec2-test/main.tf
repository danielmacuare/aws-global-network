module "test_key_pair" {
  source           = "../../../modules/create-key-pair"
  project_root     = local.project_root
  aws_region_short = local.region_short
  environment      = local.environment
  default_tags     = local.default_tags
}

module "test_vpc" {
  source           = "../../../modules/create-vpc"
  aws_region       = local.region
  aws_region_short = local.region_short
  environment      = local.environment
  vpc_name         = local.vpc_name
  vpc_cidr         = "10.0.0.0/16"
  default_tags     = local.default_tags

  public_subnets = {
    pub-0 = { az = "${local.region}a", cidr = "10.0.10.0/24" }
    pub-1 = { az = "${local.region}b", cidr = "10.0.11.0/24" }
    pub-2 = { az = "${local.region}c", cidr = "10.0.12.0/24" }
  }

  private_subnets = {
    priv-0 = { az = "${local.region}a", cidr = "10.0.0.0/24" }
    priv-1 = { az = "${local.region}b", cidr = "10.0.1.0/24" }
    priv-2 = { az = "${local.region}c", cidr = "10.0.2.0/24" }
  }

  assign_generated_ipv6_cidr_block = false
}

module "test_ec2" {
  source           = "../../../modules/create-ec2"
  aws_region       = local.region
  aws_region_short = local.region_short
  environment      = local.environment
  vpc_name         = "${local.region_short}-${local.environment}"
  vpc_id           = module.test_vpc.vpc.id
  default_tags     = local.default_tags

  public_subnets  = module.test_vpc.public_subnets
  private_subnets = module.test_vpc.private_subnets
  key_pair_name   = module.test_key_pair.key_pair_name

  # Using custom security groups from security module
  public_security_group_id  = module.security.bastion_security_group_id
  private_security_group_id = module.security.private_security_group_id
}

output "key_pair_name" {
  description = "The name of the created key pair"
  value       = module.test_key_pair.key_pair_name
}

output "key_pair_arn" {
  description = "The ARN of the created key pair"
  value       = module.test_key_pair.key_pair_arn
}

output "private_key_path" {
  description = "Path to the saved private key"
  value       = "${local.project_root}/ssh-keys/${local.region_short}-${local.environment}.pem"
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.test_vpc.vpc.id
}

output "bastion_instances" {
  description = "Bastion EC2 instances"
  value       = module.test_ec2.bastion_instances
}

output "private_instances" {
  description = "Private EC2 instances"
  value       = module.test_ec2.private_instances
}

output "bastion_security_group_ids" {
  description = "Security group IDs used by bastion instances"
  value       = module.test_ec2.bastion_security_group_ids
}

output "default_security_group_id" {
  description = "VPC default security group ID"
  value       = module.test_ec2.default_security_group_id
}
