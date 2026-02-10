resource "aws_route_table" "private" {
  for_each = var.private_subnets

  vpc_id = aws_vpc.this.id

  tags = merge(
    var.default_tags,
    {
      Name  = format("rtb-%s-%s-${each.key}", var.aws_region_short, var.environment)
      Scope = local.private_subnets_tag
    }
  )
}

resource "aws_route_table_association" "private" {
  for_each = aws_route_table.private

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = each.value["id"]
}

# Default route for private subnets to Regional NAT Gateway
# resource "aws_route" "private_default" {
#   for_each = var.private_subnets
#
#   route_table_id         = aws_route_table.private[each.key].id
#   destination_cidr_block = "0.0.0.0/0"
#   nat_gateway_id         = aws_nat_gateway.this[each.key].id
# }

resource "aws_route_table" "public" {
  for_each = var.public_subnets

  vpc_id = aws_vpc.this.id

  tags = merge(
    var.default_tags,
    {
      Name  = format("rtb-%s-%s-${each.key}", var.aws_region_short, var.environment)
      Scope = local.public_subnets_tag
    }
  )
}

resource "aws_route_table_association" "public" {
  for_each = aws_route_table.public

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = each.value["id"]
}

# Default route for public subnets to Internet Gateway
resource "aws_route" "public_default" {
  for_each = var.public_subnets

  route_table_id         = aws_route_table.public[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}
