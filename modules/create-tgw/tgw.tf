resource "aws_ec2_transit_gateway" "this" {
  description                     = "Transit Gateway for ${var.region}"
  amazon_side_asn                 = var.amazon_side_asn
  dns_support                     = var.dns_support
  vpn_ecmp_support                = var.vpn_ecmp_support
  default_route_table_association = var.default_route_table_association
  default_route_table_propagation = var.default_route_table_propagation
  multicast_support               = var.multicast_support

  tags = merge(
    var.default_tags,
    {
      Name = local.tgw_name
      type = "transit-gateway"
    }
  )
}
