# Requester side (runs in eu-west-2 — where the requester TGW lives)
resource "aws_ec2_transit_gateway_peering_attachment" "this" {
  transit_gateway_id      = data.terraform_remote_state.euw2_tgw.outputs.transit_gateway.id
  peer_transit_gateway_id = data.terraform_remote_state.euw1_tgw.outputs.transit_gateway.id
  peer_account_id         = data.terraform_remote_state.euw1_tgw.outputs.transit_gateway.owner_id
  peer_region             = "eu-west-1"

  tags = {
    Name                 = "tgw-att-euw2-euw1-pcx"
    environment          = "networking-global"
    managed_by_terraform = true
    owning_team          = "NETENG"
  }
}

# Accepter side (runs in eu-west-1)
resource "aws_ec2_transit_gateway_peering_attachment_accepter" "this" {
  provider                      = aws.euw1
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.this.id

  tags = {
    Name                 = "tgw-att-euw1-euw2-pcx"
    environment          = "networking-global"
    managed_by_terraform = true
    owning_team          = "NETENG"
  }
}

# Wait for the peering attachment to leave 'modifying' and reach 'available'
# before attempting route table associations.  The accepter can take 2-3 min
# to fully transition; 120s covers the observed worst-case with margin.
resource "time_sleep" "wait_for_peering_available" {
  depends_on      = [aws_ec2_transit_gateway_peering_attachment_accepter.this]
  create_duration = "120s"
}

# Associate peering attachment with euw2 shared route table (requester side)
resource "aws_ec2_transit_gateway_route_table_association" "euw2_peering" {
  depends_on                     = [time_sleep.wait_for_peering_available]
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.this.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw2_tgw.outputs.route_table_shared.id
}

# Associate peering attachment with euw1 shared route table (accepter side)
# Uses the accepter resource ID to ensure the accepter is fully available.
resource "aws_ec2_transit_gateway_route_table_association" "euw1_peering" {
  depends_on                     = [time_sleep.wait_for_peering_available]
  provider                       = aws.euw1
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.this.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.euw1_tgw.outputs.route_table_shared.id
}
