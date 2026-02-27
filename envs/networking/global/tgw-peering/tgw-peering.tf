# =============================================================================
# TGW Full-Mesh Peering — 4 regions, 6 attachments
# =============================================================================
#
# IP Allocation (per-environment /16 CIDRs):
#   EUW2: prod=10.0.0.0/16,  dev=10.1.0.0/16
#   EUW1: prod=10.16.0.0/16, dev=10.17.0.0/16
#   USW2: prod=10.32.0.0/16, dev=10.33.0.0/16
#   USE1: prod=10.48.0.0/16, dev=10.49.0.0/16
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

  # USE1 CIDRs
  use1_prod_cidr = "10.48.0.0/16"
  use1_dev_cidr  = "10.49.0.0/16"
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
# 3. EUW2 <-> USE1
# =============================================================================

resource "aws_ec2_transit_gateway_peering_attachment" "euw2_use1" {
  transit_gateway_id      = data.terraform_remote_state.euw2_tgw.outputs.transit_gateway.id
  peer_transit_gateway_id = data.terraform_remote_state.use1_tgw.outputs.transit_gateway.id
  peer_account_id         = data.terraform_remote_state.use1_tgw.outputs.transit_gateway.owner_id
  peer_region             = "us-east-1"

  tags = {
    Name                 = "tgw-att-euw2-use1-pcx"
    environment          = "networking-global"
    managed_by_terraform = true
    owning_team          = "NETENG"
  }
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "euw2_use1" {
  provider                      = aws.use1
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.euw2_use1.id

  tags = {
    Name                 = "tgw-att-use1-euw2-pcx"
    environment          = "networking-global"
    managed_by_terraform = true
    owning_team          = "NETENG"
  }
}

resource "time_sleep" "euw2_use1" {
  depends_on      = [aws_ec2_transit_gateway_peering_attachment_accepter.euw2_use1]
  create_duration = "120s"
}

resource "aws_ec2_transit_gateway_route_table_association" "euw2_use1_requester" {
  depends_on                     = [time_sleep.euw2_use1]
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.euw2_use1.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw2_tgw.outputs.route_table_wan.id
}

resource "aws_ec2_transit_gateway_route_table_association" "euw2_use1_accepter" {
  depends_on                     = [time_sleep.euw2_use1]
  provider                       = aws.use1
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.euw2_use1.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.use1_tgw.outputs.route_table_wan.id
}

# EUW2 -> USE1 routes
resource "aws_ec2_transit_gateway_route" "euw2_prod_to_use1" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw2_use1_requester]
  destination_cidr_block         = local.use1_prod_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.euw2_use1.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw2_tgw.outputs.route_table_prod.id
}

resource "aws_ec2_transit_gateway_route" "euw2_dev_to_use1" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw2_use1_requester]
  destination_cidr_block         = local.use1_dev_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.euw2_use1.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw2_tgw.outputs.route_table_dev.id
}

# USE1 -> EUW2 routes
resource "aws_ec2_transit_gateway_route" "use1_prod_to_euw2" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw2_use1_accepter]
  provider                       = aws.use1
  destination_cidr_block         = local.euw2_prod_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.euw2_use1.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.use1_tgw.outputs.route_table_prod.id
}

resource "aws_ec2_transit_gateway_route" "use1_dev_to_euw2" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw2_use1_accepter]
  provider                       = aws.use1
  destination_cidr_block         = local.euw2_dev_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.euw2_use1.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.use1_tgw.outputs.route_table_dev.id
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
# 5. EUW1 <-> USE1
# =============================================================================

resource "aws_ec2_transit_gateway_peering_attachment" "euw1_use1" {
  provider                = aws.euw1
  transit_gateway_id      = data.terraform_remote_state.euw1_tgw.outputs.transit_gateway.id
  peer_transit_gateway_id = data.terraform_remote_state.use1_tgw.outputs.transit_gateway.id
  peer_account_id         = data.terraform_remote_state.use1_tgw.outputs.transit_gateway.owner_id
  peer_region             = "us-east-1"

  tags = {
    Name                 = "tgw-att-euw1-use1-pcx"
    environment          = "networking-global"
    managed_by_terraform = true
    owning_team          = "NETENG"
  }
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "euw1_use1" {
  provider                      = aws.use1
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.euw1_use1.id

  tags = {
    Name                 = "tgw-att-use1-euw1-pcx"
    environment          = "networking-global"
    managed_by_terraform = true
    owning_team          = "NETENG"
  }
}

resource "time_sleep" "euw1_use1" {
  depends_on      = [aws_ec2_transit_gateway_peering_attachment_accepter.euw1_use1]
  create_duration = "120s"
}

resource "aws_ec2_transit_gateway_route_table_association" "euw1_use1_requester" {
  depends_on                     = [time_sleep.euw1_use1]
  provider                       = aws.euw1
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.euw1_use1.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw1_tgw.outputs.route_table_wan.id
}

resource "aws_ec2_transit_gateway_route_table_association" "euw1_use1_accepter" {
  depends_on                     = [time_sleep.euw1_use1]
  provider                       = aws.use1
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.euw1_use1.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.use1_tgw.outputs.route_table_wan.id
}

# EUW1 -> USE1 routes
resource "aws_ec2_transit_gateway_route" "euw1_prod_to_use1" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw1_use1_requester]
  provider                       = aws.euw1
  destination_cidr_block         = local.use1_prod_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.euw1_use1.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw1_tgw.outputs.route_table_prod.id
}

resource "aws_ec2_transit_gateway_route" "euw1_dev_to_use1" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw1_use1_requester]
  provider                       = aws.euw1
  destination_cidr_block         = local.use1_dev_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.euw1_use1.id
  transit_gateway_route_table_id = data.terraform_remote_state.euw1_tgw.outputs.route_table_dev.id
}

# USE1 -> EUW1 routes
resource "aws_ec2_transit_gateway_route" "use1_prod_to_euw1" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw1_use1_accepter]
  provider                       = aws.use1
  destination_cidr_block         = local.euw1_prod_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.euw1_use1.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.use1_tgw.outputs.route_table_prod.id
}

resource "aws_ec2_transit_gateway_route" "use1_dev_to_euw1" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.euw1_use1_accepter]
  provider                       = aws.use1
  destination_cidr_block         = local.euw1_dev_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.euw1_use1.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.use1_tgw.outputs.route_table_dev.id
}

# =============================================================================
# 6. USW2 <-> USE1
# =============================================================================

resource "aws_ec2_transit_gateway_peering_attachment" "usw2_use1" {
  provider                = aws.usw2
  transit_gateway_id      = data.terraform_remote_state.usw2_tgw.outputs.transit_gateway.id
  peer_transit_gateway_id = data.terraform_remote_state.use1_tgw.outputs.transit_gateway.id
  peer_account_id         = data.terraform_remote_state.use1_tgw.outputs.transit_gateway.owner_id
  peer_region             = "us-east-1"

  tags = {
    Name                 = "tgw-att-usw2-use1-pcx"
    environment          = "networking-global"
    managed_by_terraform = true
    owning_team          = "NETENG"
  }
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "usw2_use1" {
  provider                      = aws.use1
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.usw2_use1.id

  tags = {
    Name                 = "tgw-att-use1-usw2-pcx"
    environment          = "networking-global"
    managed_by_terraform = true
    owning_team          = "NETENG"
  }
}

resource "time_sleep" "usw2_use1" {
  depends_on      = [aws_ec2_transit_gateway_peering_attachment_accepter.usw2_use1]
  create_duration = "120s"
}

resource "aws_ec2_transit_gateway_route_table_association" "usw2_use1_requester" {
  depends_on                     = [time_sleep.usw2_use1]
  provider                       = aws.usw2
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.usw2_use1.id
  transit_gateway_route_table_id = data.terraform_remote_state.usw2_tgw.outputs.route_table_wan.id
}

resource "aws_ec2_transit_gateway_route_table_association" "usw2_use1_accepter" {
  depends_on                     = [time_sleep.usw2_use1]
  provider                       = aws.use1
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.usw2_use1.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.use1_tgw.outputs.route_table_wan.id
}

# USW2 -> USE1 routes
resource "aws_ec2_transit_gateway_route" "usw2_prod_to_use1" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.usw2_use1_requester]
  provider                       = aws.usw2
  destination_cidr_block         = local.use1_prod_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.usw2_use1.id
  transit_gateway_route_table_id = data.terraform_remote_state.usw2_tgw.outputs.route_table_prod.id
}

resource "aws_ec2_transit_gateway_route" "usw2_dev_to_use1" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.usw2_use1_requester]
  provider                       = aws.usw2
  destination_cidr_block         = local.use1_dev_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.usw2_use1.id
  transit_gateway_route_table_id = data.terraform_remote_state.usw2_tgw.outputs.route_table_dev.id
}

# USE1 -> USW2 routes
resource "aws_ec2_transit_gateway_route" "use1_prod_to_usw2" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.usw2_use1_accepter]
  provider                       = aws.use1
  destination_cidr_block         = local.usw2_prod_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.usw2_use1.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.use1_tgw.outputs.route_table_prod.id
}

resource "aws_ec2_transit_gateway_route" "use1_dev_to_usw2" {
  depends_on                     = [aws_ec2_transit_gateway_route_table_association.usw2_use1_accepter]
  provider                       = aws.use1
  destination_cidr_block         = local.usw2_dev_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.usw2_use1.transit_gateway_attachment_id
  transit_gateway_route_table_id = data.terraform_remote_state.use1_tgw.outputs.route_table_dev.id
}
