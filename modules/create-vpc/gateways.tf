resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.default_tags,
    {
      Name = format("igw-%s-%s-%s", var.aws_region_short, var.environment, var.vpc_name)
    }
  )
}

# Regional NAT Gateway with auto mode for high availability
# Auto mode automatically manages IPs across AZs - no EIP needed
resource "awscc_ec2_nat_gateway" "this" {
  vpc_id            = aws_vpc.this.id
  connectivity_type = "public"
  availability_mode = "regional"

  tags = concat(
    local.default_tags_awscc,
    [
      {
        key   = "Name"
        value = format("ngw-%s-%s-%s", var.aws_region_short, var.environment, var.vpc_name)
      },
      {
        key   = "Type"
        value = "regional-auto"
      },
      {
        key   = "ManagedBy"
        value = "terraform-awscc"
      }
    ]
  )

  depends_on = [aws_internet_gateway.this]
}