resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.default_tags,
    {
      Name = format("igw-%s-%s-%s", var.region_short, var.environment, var.cell_name)
    }
  )
}

# Regional NAT Gateway with auto mode for high availability
# Auto mode automatically manages IPs across AZs - no EIP needed
#
# time_sleep: The AWSCC Cloud Control API does not have the same retry/backoff
# logic as the standard AWS provider. A freshly-created VPC may not have
# propagated to all API endpoints by the time the NAT Gateway request fires,
# causing a "VPC does not exist" 400 error. A short buffer avoids this.
# See docs/ngw-timeout.md for full details.
resource "time_sleep" "wait_for_vpc" {
  depends_on      = [aws_vpc.this]
  create_duration = "10s"

  triggers = {
    vpc_id = aws_vpc.this.id
  }
}

resource "awscc_ec2_nat_gateway" "this" {
  # Reference VPC ID through time_sleep to enforce the wait
  vpc_id            = time_sleep.wait_for_vpc.triggers["vpc_id"]
  connectivity_type = "public"
  availability_mode = "regional"

  tags = concat(
    local.default_tags_awscc,
    [
      {
        key   = "Name"
        value = format("ngw-%s-%s-%s", var.region_short, var.environment, var.cell_name)
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

  depends_on = [aws_internet_gateway.this, time_sleep.wait_for_vpc]
}
