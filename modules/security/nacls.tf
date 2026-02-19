# Public Subnet NACL
resource "aws_network_acl" "public" {
  vpc_id     = var.vpc_id
  subnet_ids = var.public_subnet_ids

  tags = merge(var.default_tags, {
    Name = format("nacl-public-%s-%s", var.region_short, var.environment)
    type = "public-nacl"
  })
}

# Private Subnet NACL
resource "aws_network_acl" "private" {
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  tags = merge(var.default_tags, {
    Name = format("nacl-private-%s-%s", var.region_short, var.environment)
    type = "private-nacl"
  })
}

# Public NACL Rules
resource "aws_network_acl_rule" "public_inbound_ssh" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "public_inbound_http" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "public_inbound_https" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# Allow ICMP (ping) for IPv4
resource "aws_network_acl_rule" "public_inbound_icmp" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 130
  egress         = false
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  icmp_type      = -1
  icmp_code      = -1
}

# Allow ICMPv6 for IPv6
resource "aws_network_acl_rule" "public_inbound_icmpv6" {
  network_acl_id  = aws_network_acl.public.id
  rule_number     = 140
  egress          = false
  protocol        = "58"
  rule_action     = "allow"
  ipv6_cidr_block = "::/0"
  icmp_type       = -1
  icmp_code       = -1
}

# Allow return traffic from established TCP connections (e.g. SSH to private subnets)
resource "aws_network_acl_rule" "public_inbound_ephemeral" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 150
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "10.0.0.0/8"
  from_port      = 1024
  to_port        = 65535
}

# Public NACL Egress Rules
resource "aws_network_acl_rule" "public_outbound_all" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "public_outbound_ipv6" {
  network_acl_id  = aws_network_acl.public.id
  rule_number     = 110
  egress          = true
  protocol        = "-1"
  rule_action     = "allow"
  ipv6_cidr_block = "::/0"
  from_port       = 0
  to_port         = 0
}

# Private NACL Rules
resource "aws_network_acl_rule" "private_inbound_all" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 0
  to_port        = 0
}

# Allow all inbound from same-environment cells (cross-cell traffic via TGW)
resource "aws_network_acl_rule" "private_inbound_env_supernet" {
  count          = var.env_supernet_cidr != "" ? 1 : 0
  network_acl_id = aws_network_acl.private.id
  rule_number    = 110
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.env_supernet_cidr
  from_port      = 0
  to_port        = 0
}

# Private NACL Egress Rules
resource "aws_network_acl_rule" "private_outbound_all" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "private_outbound_ipv6" {
  network_acl_id  = aws_network_acl.private.id
  rule_number     = 110
  egress          = true
  protocol        = "-1"
  rule_action     = "allow"
  ipv6_cidr_block = "::/0"
  from_port       = 0
  to_port         = 0
}
