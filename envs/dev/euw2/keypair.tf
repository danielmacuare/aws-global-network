module "key_pair" {
  source       = "../../../modules/create-key-pair"
  project_root = local.project_root
  region_short = local.region_short
  environment  = local.environment
  default_tags = local.default_tags
}
