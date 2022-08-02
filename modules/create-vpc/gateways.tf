resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.default_tags,
    {
      Name = format("igw-%s-%s", var.aws_region_short, var.environment)
    }
  )
}

resource "aws_eip" "nat_gateways" {
  count = length(var.private_subnets)
  vpc   = true

  tags = merge(
    var.default_tags,
    {
      Name = format("eip-${count.index}-ngw-%s-%s", var.aws_region_short, var.environment)
    }
  )
}

resource "aws_nat_gateway" "this" {
  count = length(var.private_subnets)

  allocation_id = aws_eip.nat_gateways[count.index].id
  subnet_id     = values(aws_subnet.private)[count.index].id

  tags = merge(
    var.default_tags,
    {
      name = format("ngw${count.index}-%s-%s", var.aws_region_short, var.environment)
    }
  )
}