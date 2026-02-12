locals {
  attachment_name = format("tgw-att-%s-%s-%s", var.region_short, var.environment, var.vpc_name)
}
