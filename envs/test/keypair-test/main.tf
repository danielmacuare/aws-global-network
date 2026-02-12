module "test_key_pair" {
  source       = "../../../modules/create-key-pair"
  project_root = local.project_root
  region_short = local.region_short
  environment  = local.environment
  default_tags = local.default_tags
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
