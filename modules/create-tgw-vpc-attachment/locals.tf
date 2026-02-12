locals {
  attachment_name = format("tgw-att-%s-%s-%s", var.aws_region_short, var.environment, var.vpc_name)
}
