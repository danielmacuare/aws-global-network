output "peering_euw2_euw1" {
  description = "TGW peering attachment euw2 <-> euw1"
  value = {
    requester = aws_ec2_transit_gateway_peering_attachment.euw2_euw1
    accepter  = aws_ec2_transit_gateway_peering_attachment_accepter.euw2_euw1
  }
}

output "peering_euw2_usw2" {
  description = "TGW peering attachment euw2 <-> usw2"
  value = {
    requester = aws_ec2_transit_gateway_peering_attachment.euw2_usw2
    accepter  = aws_ec2_transit_gateway_peering_attachment_accepter.euw2_usw2
  }
}

output "peering_euw2_use1" {
  description = "TGW peering attachment euw2 <-> use1"
  value = {
    requester = aws_ec2_transit_gateway_peering_attachment.euw2_use1
    accepter  = aws_ec2_transit_gateway_peering_attachment_accepter.euw2_use1
  }
}

output "peering_euw1_usw2" {
  description = "TGW peering attachment euw1 <-> usw2"
  value = {
    requester = aws_ec2_transit_gateway_peering_attachment.euw1_usw2
    accepter  = aws_ec2_transit_gateway_peering_attachment_accepter.euw1_usw2
  }
}

output "peering_euw1_use1" {
  description = "TGW peering attachment euw1 <-> use1"
  value = {
    requester = aws_ec2_transit_gateway_peering_attachment.euw1_use1
    accepter  = aws_ec2_transit_gateway_peering_attachment_accepter.euw1_use1
  }
}

output "peering_usw2_use1" {
  description = "TGW peering attachment usw2 <-> use1"
  value = {
    requester = aws_ec2_transit_gateway_peering_attachment.usw2_use1
    accepter  = aws_ec2_transit_gateway_peering_attachment_accepter.usw2_use1
  }
}
