# =============================================================================
# TGW Full-Mesh Peering — 4 regions, 6 attachments
# =============================================================================
#
# IP Allocation (per-environment /16 CIDRs):
#   EUW2: prod=10.0.0.0/16,  dev=10.1.0.0/16
#   EUW1: prod=10.16.0.0/16, dev=10.17.0.0/16
#   USW2: prod=10.32.0.0/16, dev=10.33.0.0/16
#   USW1: prod=10.48.0.0/16, dev=10.49.0.0/16
#
# Routing strategy:
#   - Each peering attachment is associated with the WAN route table on both sides.
#   - Static routes use per-environment /16 CIDRs to enforce isolation:
#       prod route table -> remote prod CIDR only
#       dev route table  -> remote dev CIDR only
#   - Prod<->dev cross-environment communication is blocked because
#     each route table only carries a route to its matching environment.
# =============================================================================

locals {
  # EUW2 CIDRs
  euw2_prod_cidr = "10.0.0.0/16"
  euw2_dev_cidr  = "10.1.0.0/16"

  # EUW1 CIDRs
  euw1_prod_cidr = "10.16.0.0/16"
  euw1_dev_cidr  = "10.17.0.0/16"

  # USW2 CIDRs
  usw2_prod_cidr = "10.32.0.0/16"
  usw2_dev_cidr  = "10.33.0.0/16"

  # USW1 CIDRs
  usw1_prod_cidr = "10.48.0.0/16"
  usw1_dev_cidr  = "10.49.0.0/16"
}

# =============================================================================
# State migrations — rename .this -> .euw2_euw1 for consistency with new
# peering blocks. These moved blocks prevent destroy/recreate on first apply.
# =============================================================================

moved {
  from = aws_ec2_transit_gateway_peering_attachment.this
  to   = aws_ec2_transit_gateway_peering_attachment.euw2_euw1
}

moved {
  from = aws_ec2_transit_gateway_peering_attachment_accepter.this
  to   = aws_ec2_transit_gateway_peering_attachment_accepter.euw2_euw1
}

moved {
  from = time_sleep.wait_for_peering_available
  to   = time_sleep.euw2_euw1
}

moved {
  from = aws_ec2_transit_gateway_route_table_association.euw2_peering
  to   = aws_ec2_transit_gateway_route_table_association.euw2_euw1_requester
}

moved {
  from = aws_ec2_transit_gateway_route_table_association.euw1_peering
  to   = aws_ec2_transit_gateway_route_table_association.euw2_euw1_accepter
}

# =============================================================================
# 1. EUW2 <-> EUW1 (existing)
# =============================================================================

resource "aws_ec2_transit_gateway_peering_attachment" "euw2_euw1" {
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

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "euw2_euw1" {
  provider                      = aws.euw1
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.euw2_euw1.id

  tags = {
    Name                 = "tgw-att-euw1-euw2-pcx"
    environment          = "networking-global"
    managed_by_terraform = true
    owning_team          = "NETENG"
  }
}

resource "time_sleep" "euw2_euw1" {
  depends_on      = [aws_ec2_transit_gateway_peering_attachment_accepter.euw2_euw1]
  create_duration = "120s"
}

resource "aws_ec2_transit_gateway_route_table_association" "euw2_euw1_requester" {
  depends_on                     = [time_sleep.euw2_euw1]
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.euw2_euw1.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw2_tgw.outputs.route_table_wan.id
}

resource "aws_ec2_transit_gateway_route_table_association" "euw2_euw1_accepter" {
  depends_on                     = [time_sleep.euw2_euw1]
  provider                       = aws.euw1
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.euw2_euw1.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.euw1_tgw.outputs.route_table_wan.id
}

# EUW2 -> EUW1 routes
resource "aws_ec2_transit_gateway_route" "euw2_prod_to_euw1" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw2_euw1_requester]
  destination_cidr_block         = local.euw1_prod_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.euw2_euw1.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw2_tgw.outputs.route_table_prod.id
}

resource "aws_ec2_transit_gateway_route" "euw2_dev_to_euw1" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw2_euw1_requester]
  destination_cidr_block         = local.euw1_dev_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.euw2_euw1.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw2_tgw.outputs.route_table_dev.id
}

# EUW1 -> EUW2 routes
resource "aws_ec2_transit_gateway_route" "euw1_prod_to_euw2" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw2_euw1_accepter]
  provider                       = aws.euw1
  destination_cidr_block         = local.euw2_prod_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.euw2_euw1.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.euw1_tgw.outputs.route_table_prod.id
}

resource "aws_ec2_transit_gateway_route" "euw1_dev_to_euw2" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw2_euw1_accepter]
  provider                       = aws.euw1
  destination_cidr_block         = local.euw2_dev_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.euw2_euw1.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.euw1_tgw.outputs.route_table_dev.id
}

# =============================================================================
# 2. EUW2 <-> USW2
# =============================================================================

resource "aws_ec2_transit_gateway_peering_attachment" "euw2_usw2" {
  transit_gateway_id      = data.terraform_remote_state.euw2_tgw.outputs.transit_gateway.id
  peer_transit_gateway_id = data.terraform_remote_state.usw2_tgw.outputs.transit_gateway.id
  peer_account_id         = data.terraform_remote_state.usw2_tgw.outputs.transit_gateway.owner_id
  peer_region             = "us-west-2"

  tags = {
    Name                 = "tgw-att-euw2-usw2-pcx"
    environment          = "networking-global"
    managed_by_terraform = true
    owning_team          = "NETENG"
  }
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "euw2_usw2" {
  provider                      = aws.usw2
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.euw2_usw2.id

  tags = {
    Name                 = "tgw-att-usw2-euw2-pcx"
    environment          = "networking-global"
    managed_by_terraform = true
    owning_team          = "NETENG"
  }
}

resource "time_sleep" "euw2_usw2" {
  depends_on      = [aws_ec2_transit_gateway_peering_attachment_accepter.euw2_usw2]
  create_duration = "120s"
}

resource "aws_ec2_transit_gateway_route_table_association" "euw2_usw2_requester" {
  depends_on                     = [time_sleep.euw2_usw2]
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.euw2_usw2.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw2_tgw.outputs.route_table_wan.id
}

resource "aws_ec2_transit_gateway_route_table_association" "euw2_usw2_accepter" {
  depends_on                     = [time_sleep.euw2_usw2]
  provider                       = aws.usw2
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.euw2_usw2.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.usw2_tgw.outputs.route_table_wan.id
}

# EUW2 -> USW2 routes
resource "aws_ec2_transit_gateway_route" "euw2_prod_to_usw2" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw2_usw2_requester]
  destination_cidr_block         = local.usw2_prod_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.euw2_usw2.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw2_tgw.outputs.route_table_prod.id
}

resource "aws_ec2_transit_gateway_route" "euw2_dev_to_usw2" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw2_usw2_requester]
  destination_cidr_block         = local.usw2_dev_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.euw2_usw2.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw2_tgw.outputs.route_table_dev.id
}

# USW2 -> EUW2 routes
resource "aws_ec2_transit_gateway_route" "usw2_prod_to_euw2" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw2_usw2_accepter]
  provider                       = aws.usw2
  destination_cidr_block         = local.euw2_prod_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.euw2_usw2.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.usw2_tgw.outputs.route_table_prod.id
}

resource "aws_ec2_transit_gateway_route" "usw2_dev_to_euw2" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw2_usw2_accepter]
  provider                       = aws.usw2
  destination_cidr_block         = local.euw2_dev_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.euw2_usw2.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.usw2_tgw.outputs.route_table_dev.id
}

# =============================================================================
# 3. EUW2 <-> USW1
# =============================================================================

resource "aws_ec2_transit_gateway_peering_attachment" "euw2_usw1" {
  transit_gateway_id      = data.terraform_remote_state.euw2_tgw.outputs.transit_gateway.id
  peer_transit_gateway_id = data.terraform_remote_state.usw1_tgw.outputs.transit_gateway.id
  peer_account_id         = data.terraform_remote_state.usw1_tgw.outputs.transit_gateway.owner_id
  peer_region             = "us-west-1"

  tags = {
    Name                 = "tgw-att-euw2-usw1-pcx"
    environment          = "networking-global"
    managed_by_terraform = true
    owning_team          = "NETENG"
  }
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "euw2_usw1" {
  provider                      = aws.usw1
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.euw2_usw1.id

  tags = {
    Name                 = "tgw-att-usw1-euw2-pcx"
    environment          = "networking-global"
    managed_by_terraform = true
    owning_team          = "NETENG"
  }
}

resource "time_sleep" "euw2_usw1" {
  depends_on      = [aws_ec2_transit_gateway_peering_attachment_accepter.euw2_usw1]
  create_duration = "120s"
}

resource "aws_ec2_transit_gateway_route_table_association" "euw2_usw1_requester" {
  depends_on                     = [time_sleep.euw2_usw1]
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.euw2_usw1.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw2_tgw.outputs.route_table_wan.id
}

resource "aws_ec2_transit_gateway_route_table_association" "euw2_usw1_accepter" {
  depends_on                     = [time_sleep.euw2_usw1]
  provider                       = aws.usw1
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.euw2_usw1.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.usw1_tgw.outputs.route_table_wan.id
}

# EUW2 -> USW1 routes
resource "aws_ec2_transit_gateway_route" "euw2_prod_to_usw1" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw2_usw1_requester]
  destination_cidr_block         = local.usw1_prod_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.euw2_usw1.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw2_tgw.outputs.route_table_prod.id
}

resource "aws_ec2_transit_gateway_route" "euw2_dev_to_usw1" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw2_usw1_requester]
  destination_cidr_block         = local.usw1_dev_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.euw2_usw1.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw2_tgw.outputs.route_table_dev.id
}

# USW1 -> EUW2 routes
resource "aws_ec2_transit_gateway_route" "usw1_prod_to_euw2" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw2_usw1_accepter]
  provider                       = aws.usw1
  destination_cidr_block         = local.euw2_prod_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.euw2_usw1.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.usw1_tgw.outputs.route_table_prod.id
}

resource "aws_ec2_transit_gateway_route" "usw1_dev_to_euw2" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw2_usw1_accepter]
  provider                       = aws.usw1
  destination_cidr_block         = local.euw2_dev_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.euw2_usw1.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.usw1_tgw.outputs.route_table_dev.id
}

# =============================================================================
# 4. EUW1 <-> USW2
# =============================================================================

resource "aws_ec2_transit_gateway_peering_attachment" "euw1_usw2" {
  provider                = aws.euw1
  transit_gateway_id      = data.terraform_remote_state.euw1_tgw.outputs.transit_gateway.id
  peer_transit_gateway_id = data.terraform_remote_state.usw2_tgw.outputs.transit_gateway.id
  peer_account_id         = data.terraform_remote_state.usw2_tgw.outputs.transit_gateway.owner_id
  peer_region             = "us-west-2"

  tags = {
    Name                 = "tgw-att-euw1-usw2-pcx"
    environment          = "networking-global"
    managed_by_terraform = true
    owning_team          = "NETENG"
  }
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "euw1_usw2" {
  provider                      = aws.usw2
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.euw1_usw2.id

  tags = {
    Name                 = "tgw-att-usw2-euw1-pcx"
    environment          = "networking-global"
    managed_by_terraform = true
    owning_team          = "NETENG"
  }
}

resource "time_sleep" "euw1_usw2" {
  depends_on      = [aws_ec2_transit_gateway_peering_attachment_accepter.euw1_usw2]
  create_duration = "120s"
}

resource "aws_ec2_transit_gateway_route_table_association" "euw1_usw2_requester" {
  depends_on                     = [time_sleep.euw1_usw2]
  provider                       = aws.euw1
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.euw1_usw2.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw1_tgw.outputs.route_table_wan.id
}

resource "aws_ec2_transit_gateway_route_table_association" "euw1_usw2_accepter" {
  depends_on                     = [time_sleep.euw1_usw2]
  provider                       = aws.usw2
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.euw1_usw2.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.usw2_tgw.outputs.route_table_wan.id
}

# EUW1 -> USW2 routes
resource "aws_ec2_transit_gateway_route" "euw1_prod_to_usw2" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw1_usw2_requester]
  provider                       = aws.euw1
  destination_cidr_block         = local.usw2_prod_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.euw1_usw2.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw1_tgw.outputs.route_table_prod.id
}

resource "aws_ec2_transit_gateway_route" "euw1_dev_to_usw2" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw1_usw2_requester]
  provider                       = aws.euw1
  destination_cidr_block         = local.usw2_dev_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.euw1_usw2.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw1_tgw.outputs.route_table_dev.id
}

# USW2 -> EUW1 routes
resource "aws_ec2_transit_gateway_route" "usw2_prod_to_euw1" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw1_usw2_accepter]
  provider                       = aws.usw2
  destination_cidr_block         = local.euw1_prod_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.euw1_usw2.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.usw2_tgw.outputs.route_table_prod.id
}

resource "aws_ec2_transit_gateway_route" "usw2_dev_to_euw1" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw1_usw2_accepter]
  provider                       = aws.usw2
  destination_cidr_block         = local.euw1_dev_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.euw1_usw2.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.usw2_tgw.outputs.route_table_dev.id
}

# =============================================================================
# 5. EUW1 <-> USW1
# =============================================================================

resource "aws_ec2_transit_gateway_peering_attachment" "euw1_usw1" {
  provider                = aws.euw1
  transit_gateway_id      = data.terraform_remote_state.euw1_tgw.outputs.transit_gateway.id
  peer_transit_gateway_id = data.terraform_remote_state.usw1_tgw.outputs.transit_gateway.id
  peer_account_id         = data.terraform_remote_state.usw1_tgw.outputs.transit_gateway.owner_id
  peer_region             = "us-west-1"

  tags = {
    Name                 = "tgw-att-euw1-usw1-pcx"
    environment          = "networking-global"
    managed_by_terraform = true
    owning_team          = "NETENG"
  }
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "euw1_usw1" {
  provider                      = aws.usw1
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.euw1_usw1.id

  tags = {
    Name                 = "tgw-att-usw1-euw1-pcx"
    environment          = "networking-global"
    managed_by_terraform = true
    owning_team          = "NETENG"
  }
}

resource "time_sleep" "euw1_usw1" {
  depends_on      = [aws_ec2_transit_gateway_peering_attachment_accepter.euw1_usw1]
  create_duration = "120s"
}

resource "aws_ec2_transit_gateway_route_table_association" "euw1_usw1_requester" {
  depends_on                     = [time_sleep.euw1_usw1]
  provider                       = aws.euw1
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.euw1_usw1.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw1_tgw.outputs.route_table_wan.id
}

resource "aws_ec2_transit_gateway_route_table_association" "euw1_usw1_accepter" {
  depends_on                     = [time_sleep.euw1_usw1]
  provider                       = aws.usw1
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.euw1_usw1.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.usw1_tgw.outputs.route_table_wan.id
}

# EUW1 -> USW1 routes
resource "aws_ec2_transit_gateway_route" "euw1_prod_to_usw1" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw1_usw1_requester]
  provider                       = aws.euw1
  destination_cidr_block         = local.usw1_prod_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.euw1_usw1.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw1_tgw.outputs.route_table_prod.id
}

resource "aws_ec2_transit_gateway_route" "euw1_dev_to_usw1" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw1_usw1_requester]
  provider                       = aws.euw1
  destination_cidr_block         = local.usw1_dev_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.euw1_usw1.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw1_tgw.outputs.route_table_dev.id
}

# USW1 -> EUW1 routes
resource "aws_ec2_transit_gateway_route" "usw1_prod_to_euw1" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw1_usw1_accepter]
  provider                       = aws.usw1
  destination_cidr_block         = local.euw1_prod_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.euw1_usw1.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.usw1_tgw.outputs.route_table_prod.id
}

resource "aws_ec2_transit_gateway_route" "usw1_dev_to_euw1" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw1_usw1_accepter]
  provider                       = aws.usw1
  destination_cidr_block         = local.euw1_dev_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.euw1_usw1.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.usw1_tgw.outputs.route_table_dev.id
}

# =============================================================================
# 6. USW2 <-> USW1
# =============================================================================

resource "aws_ec2_transit_gateway_peering_attachment" "usw2_usw1" {
  provider                = aws.usw2
  transit_gateway_id      = data.terraform_remote_state.usw2_tgw.outputs.transit_gateway.id
  peer_transit_gateway_id = data.terraform_remote_state.usw1_tgw.outputs.transit_gateway.id
  peer_account_id         = data.terraform_remote_state.usw1_tgw.outputs.transit_gateway.owner_id
  peer_region             = "us-west-1"

  tags = {
    Name                 = "tgw-att-usw2-usw1-pcx"
    environment          = "networking-global"
    managed_by_terraform = true
    owning_team          = "NETENG"
  }
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "usw2_usw1" {
  provider                      = aws.usw1
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.usw2_usw1.id

  tags = {
    Name                 = "tgw-att-usw1-usw2-pcx"
    environment          = "networking-global"
    managed_by_terraform = true
    owning_team          = "NETENG"
  }
}

resource "time_sleep" "usw2_usw1" {
  depends_on      = [aws_ec2_transit_gateway_peering_attachment_accepter.usw2_usw1]
  create_duration = "120s"
}

resource "aws_ec2_transit_gateway_route_table_association" "usw2_usw1_requester" {
  depends_on                     = [time_sleep.usw2_usw1]
  provider                       = aws.usw2
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.usw2_usw1.id
  transit_gateway_route_table_id = data.terraform_remote_state.usw2_tgw.outputs.route_table_wan.id
}

resource "aws_ec2_transit_gateway_route_table_association" "usw2_usw1_accepter" {
  depends_on                     = [time_sleep.usw2_usw1]
  provider                       = aws.usw1
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.usw2_usw1.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.usw1_tgw.outputs.route_table_wan.id
}

# USW2 -> USW1 routes
resource "aws_ec2_transit_gateway_route" "usw2_prod_to_usw1" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.usw2_usw1_requester]
  provider                       = aws.usw2
  destination_cidr_block         = local.usw1_prod_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.usw2_usw1.id
  transit_gateway_route_table_id = data.terraform_remote_state.usw2_tgw.outputs.route_table_prod.id
}

resource "aws_ec2_transit_gateway_route" "usw2_dev_to_usw1" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.usw2_usw1_requester]
  provider                       = aws.usw2
  destination_cidr_block         = local.usw1_dev_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.usw2_usw1.id
  transit_gateway_route_table_id = data.terraform_remote_state.usw2_tgw.outputs.route_table_dev.id
}

# USW1 -> USW2 routes
resource "aws_ec2_transit_gateway_route" "usw1_prod_to_usw2" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.usw2_usw1_accepter]
  provider                       = aws.usw1
  destination_cidr_block         = local.usw2_prod_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.usw2_usw1.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.usw1_tgw.outputs.route_table_prod.id
}

resource "aws_ec2_transit_gateway_route" "usw1_dev_to_usw2" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.usw2_usw1_accepter]
  provider                       = aws.usw1
  destination_cidr_block         = local.usw2_dev_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.usw2_usw1.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.usw1_tgw.outputs.route_table_dev.id
}
