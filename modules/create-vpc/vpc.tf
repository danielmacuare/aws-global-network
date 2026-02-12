resource "aws_vpc" "this" {
  cidr_block                       = var.vpc_cidr
  assign_generated_ipv6_cidr_block = var.assign_generated_ipv6_cidr_block
  enable_dns_hostnames             = true

  tags = merge(
    var.default_tags,
    {
      Name = format("vpc-%s-%s-%s", var.region_short, var.environment, var.vpc_name)
    }
  )
}

resource "aws_egress_only_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id


  tags = merge(
    var.default_tags,
    {
      Name = format("egipv6-igw-%s-%s-%s", var.region_short, var.environment, var.vpc_name)
    }
  )
}
