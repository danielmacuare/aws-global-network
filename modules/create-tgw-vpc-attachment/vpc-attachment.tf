resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids

  dns_support                                     = var.dns_support
  appliance_mode_support                          = var.appliance_mode_support
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(
    var.default_tags,
    {
      Name        = local.attachment_name
      type        = "transit-gateway-attachment"
      environment = var.environment
    }
  )
}

resource "aws_ec2_transit_gateway_route_table_association" "this" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = var.transit_gateway_route_table_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "this" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = var.transit_gateway_route_table_id
}

# Also propagate into the WAN route table so the peering attachment
# (associated with rt-wan) can deliver inbound cross-region traffic.
resource "aws_ec2_transit_gateway_route_table_propagation" "wan" {
  count                          = var.transit_gateway_wan_route_table_id != null ? 1 : 0
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = var.transit_gateway_wan_route_table_id
}

# VPC-side route: send the TGW supernet from each private subnet route table
# to the TGW, enabling east-west traffic between cells and regions.
resource "aws_route" "tgw" {
  for_each = var.private_route_table_ids

  route_table_id         = each.value
  destination_cidr_block = var.tgw_supernet_cidr
  transit_gateway_id     = var.transit_gateway_id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}
