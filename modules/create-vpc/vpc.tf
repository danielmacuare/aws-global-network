resource "aws_vpc" "this" {
  cidr_block                       = var.vpc_cidr
  assign_generated_ipv6_cidr_block = var.assign_generated_ipv6_cidr_block
  enable_dns_hostnames = true

  tags = merge(
    var.default_tags,
    {
      Name = format("vpc-%s-%s-%s", var.aws_region_short, var.environment, var.vpc_name)
    }
  )
}
