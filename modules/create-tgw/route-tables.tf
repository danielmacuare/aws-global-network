resource "aws_ec2_transit_gateway_route_table" "prod" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(
    var.default_tags,
    {
      Name           = format("rt-tgw-%s-prod", var.region_short)
      type           = "transit-gateway-route-table"
      routing_policy = "prod"
      environment    = "prod"
    }
  )
}

resource "aws_ec2_transit_gateway_route_table" "dev" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(
    var.default_tags,
    {
      Name           = format("rt-tgw-%s-dev", var.region_short)
      type           = "transit-gateway-route-table"
      routing_policy = "dev"
      environment    = "dev"
    }
  )
}

resource "aws_ec2_transit_gateway_route_table" "shared" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(
    var.default_tags,
    {
      Name           = format("rt-tgw-%s-shared", var.region_short)
      type           = "transit-gateway-route-table"
      routing_policy = "shared"
      environment    = "shared"
    }
  )
}

resource "aws_ec2_transit_gateway_route_table" "wan" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(
    var.default_tags,
    {
      Name           = format("rt-tgw-%s-wan", var.region_short)
      type           = "transit-gateway-route-table"
      routing_policy = "wan"
      environment    = "networking"
    }
  )
}
