# =============================================================================
# TGW Peering: euw2 (requester) <-> euw1 (accepter)
# =============================================================================
#
# IP Allocation (verified from cell locals.tf files):
#   EUW2 prod (cell0000): 10.0.0.0/16
#   EUW2 dev  (cell1000): 10.1.0.0/16
#   EUW1 prod (cell2000): 10.16.0.0/16
#   EUW1 dev  (cell3000): 10.17.0.0/16
#
# Routing strategy:
#   - Peering attachment is associated with the dedicated WAN route table
#     (one association per side — TGW allows only one).
#   - Static routes use per-environment /16 CIDRs to enforce isolation:
#       prod route table -> remote prod CIDR only
#       dev route table  -> remote dev CIDR only
#   - Prod<->dev cross-environment communication is blocked because
#     each route table only carries a route to its matching environment.
# =============================================================================

locals {
  # EUW2 CIDRs — verified from cell locals.tf files
  euw2_prod_cidr = "10.0.0.0/16"
  euw2_dev_cidr  = "10.1.0.0/16"

  # EUW1 CIDRs — verified from cell locals.tf files
  euw1_prod_cidr = "10.16.0.0/16"
  euw1_dev_cidr  = "10.17.0.0/16"
}

# -----------------------------------------------------------------------------
# Peering attachment
# -----------------------------------------------------------------------------

# Requester side (runs in eu-west-2)
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

# -----------------------------------------------------------------------------
# Wait for peering to reach 'available'
# -----------------------------------------------------------------------------

resource "time_sleep" "wait_for_peering_available" {
  depends_on      = [aws_ec2_transit_gateway_peering_attachment_accepter.this]
  create_duration = "120s"
}

# -----------------------------------------------------------------------------
# Route table associations — peering attachment -> WAN route table
# -----------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_route_table_association" "euw2_peering" {
  depends_on                     = [time_sleep.wait_for_peering_available]
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.this.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw2_tgw.outputs.route_table_wan.id
}

resource "aws_ec2_transit_gateway_route_table_association" "euw1_peering" {
  depends_on                     = [time_sleep.wait_for_peering_available]
  provider                       = aws.euw1
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.this.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.euw1_tgw.outputs.route_table_wan.id
}

# -----------------------------------------------------------------------------
# Static routes — EUW2 side
# -----------------------------------------------------------------------------
# Each route table only carries a route to its matching environment CIDR in
# euw1, enforcing prod<->prod and dev<->dev isolation across regions.

resource "aws_ec2_transit_gateway_route" "euw2_prod_to_euw1" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw2_peering]
  destination_cidr_block         = local.euw1_prod_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.this.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw2_tgw.outputs.route_table_prod.id
}

resource "aws_ec2_transit_gateway_route" "euw2_dev_to_euw1" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw2_peering]
  destination_cidr_block         = local.euw1_dev_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.this.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw2_tgw.outputs.route_table_dev.id
}

# -----------------------------------------------------------------------------
# Static routes — EUW1 side
# -----------------------------------------------------------------------------
# Each route table only carries a route to its matching environment CIDR in
# euw2, enforcing prod<->prod and dev<->dev isolation across regions.

resource "aws_ec2_transit_gateway_route" "euw1_prod_to_euw2" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw1_peering]
  provider                       = aws.euw1
  destination_cidr_block         = local.euw2_prod_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.this.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.euw1_tgw.outputs.route_table_prod.id
}

resource "aws_ec2_transit_gateway_route" "euw1_dev_to_euw2" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw1_peering]
  provider                       = aws.euw1
  destination_cidr_block         = local.euw2_dev_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.this.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.euw1_tgw.outputs.route_table_dev.id
}
