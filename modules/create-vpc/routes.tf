resource "aws_route_table" "private" {
  for_each = var.private_subnets

  vpc_id = aws_vpc.this.id

  tags = merge(
    var.default_tags,
    {
      Name  = format("sub-%s-%s-${each.key}", var.aws_region_short, var.environment)
      Scope = local.private_subnets_tag
    }
  )
}

#resource "aws_route_table_association" "private" {
#for_each = aws_route_table.private

#subnet_id      = aws_subnet.public[count.index].id
#route_table_id = each.value["id"]

#}

resource "aws_route_table" "public" {
  for_each = var.public_subnets

  vpc_id = aws_vpc.this.id

  tags = merge(
    var.default_tags,
    {
      Name  = format("sub-%s-%s-${each.key}", var.aws_region_short, var.environment)
      Scope = local.public_subnets_tag
    }
  )
}


#resource "aws_route" "private_subnet_default" {
#route_table_id         = aws_route_table.public.id
#destination_cidr_block = "0.0.0.0/0"
#gateway_id             = aws_internet_gateway.main.id
#}


#resource "aws_route" "public_subnet_default" {
#route_table_id         = aws_route_table.public.id
#destination_cidr_block = "0.0.0.0/0"
#gateway_id             = aws_internet_gateway.main.id
#}
