output "peering_attachment" {
  description = "TGW peering attachment (requester side, eu-west-2)"
  value       = aws_ec2_transit_gateway_peering_attachment.this
}

output "peering_attachment_accepter" {
  description = "TGW peering attachment accepter (eu-west-1)"
  value       = aws_ec2_transit_gateway_peering_attachment_accepter.this
}
