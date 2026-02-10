resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.default_tags,
    {
      Name = format("igw-%s-%s", var.aws_region_short, var.environment)
    }
  )
}

# resource "aws_eip" "nat_gateways" {
#   for_each = var.public_subnets
#   domain   = "vpc"
#
#   tags = merge(
#     var.default_tags,
#     {
#       Name = format("eip-%s-ngw-%s-%s", each.key, var.aws_region_short, var.environment)
#     }
#   )
# }

# resource "aws_nat_gateway" "this" {
#   for_each = var.public_subnets
#
#   allocation_id = aws_eip.nat_gateways[each.key].id
#   subnet_id     = aws_subnet.public[each.key].id
#
#   tags = merge(
#     var.default_tags,
#     {
#       Name = format("ngw-%s-%s-%s", each.key, var.aws_region_short, var.environment)
#     }
#   )
#
#   depends_on = [aws_internet_gateway.this]
# }