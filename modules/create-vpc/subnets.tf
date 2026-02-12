
resource "aws_subnet" "private" {
  for_each = var.private_subnets

  availability_zone = each.value["az"]
  cidr_block        = each.value["cidr"]
  vpc_id            = aws_vpc.this.id
  # Enable IPv6 address assignment only if VPC has IPv6 CIDR block
  assign_ipv6_address_on_creation = var.assign_generated_ipv6_cidr_block
  # Assign IPv6 CIDR from VPC block if enabled
  ipv6_cidr_block = var.assign_generated_ipv6_cidr_block ? cidrsubnet(aws_vpc.this.ipv6_cidr_block, 8, index(keys(var.private_subnets), each.key)) : null
  # Enable AAAA DNS records only if IPv6 is enabled
  enable_resource_name_dns_aaaa_record_on_launch = var.assign_generated_ipv6_cidr_block

  tags = merge(
    var.default_tags,
    {
      Name  = format("sub-%s-%s-${each.key}", var.region_short, var.environment)
      scope = "private"
    }
  )
}

resource "aws_subnet" "public" {
  for_each = var.public_subnets

  availability_zone = each.value["az"]
  cidr_block        = each.value["cidr"]
  vpc_id            = aws_vpc.this.id
  # Enable IPv6 address assignment only if VPC has IPv6 CIDR block
  assign_ipv6_address_on_creation = var.assign_generated_ipv6_cidr_block
  # Assign IPv6 CIDR from VPC block if enabled (offset by number of private subnets)
  ipv6_cidr_block = var.assign_generated_ipv6_cidr_block ? cidrsubnet(aws_vpc.this.ipv6_cidr_block, 8, index(keys(var.public_subnets), each.key) + length(var.private_subnets)) : null
  # Enable AAAA DNS records only if IPv6 is enabled
  enable_resource_name_dns_aaaa_record_on_launch = var.assign_generated_ipv6_cidr_block

  tags = merge(
    var.default_tags,
    {
      Name  = format("sub-%s-%s-${each.key}", var.region_short, var.environment)
      scope = "public"
    }
  )
}
