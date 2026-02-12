module "tgw" {
  source = "../../../../modules/create-tgw"

  region          = local.region
  region_short    = local.region_short
  amazon_side_asn = local.amazon_side_asn
  default_tags    = local.default_tags
}
