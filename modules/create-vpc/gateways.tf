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

  lifecycle {
  # 1 - When you create a NAT Gateway in "regional" - "auto" mode, AWS automatically assigns 
  # and manages the Elastic IP (EIP) addresses and their associations.
  # 2 - After the NAT Gateway is created, AWS populates the availability_zone_addresses attribute with these details.
  # 3 - Because these values weren't in the original Terraform code, Terraform sees them as "extra" or 
  # "unexpected" changes during the next run and tries to remove them.
    ignore_changes = [
      availability_zone_addresses
    ]
  }

  depends_on = [aws_internet_gateway.this]
}