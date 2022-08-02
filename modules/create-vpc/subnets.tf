
resource "aws_subnet" "private" {
  for_each = var.private_subnets

  availability_zone = each.value["az"]
  cidr_block        = each.value["cidr"]
  vpc_id            = aws_vpc.this.id

  tags = merge(
    var.default_tags,
    {
      Name  = format("sub-%s-%s-${each.key}", var.aws_region_short, var.environment)
      Scope = "private"
    }
  )
}

resource "aws_subnet" "public" {
  for_each = var.public_subnets

  availability_zone = each.value["az"]
  cidr_block        = each.value["cidr"]
  vpc_id            = aws_vpc.this.id

  tags = merge(
    var.default_tags,
    {
      Name  = format("sub-%s-%s-${each.key}", var.aws_region_short, var.environment)
      Scope = "public"
    }
  )
}
