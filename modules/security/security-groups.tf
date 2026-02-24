# Public Security Group (Bastion)
resource "aws_security_group" "bastion" {
  name_prefix = "bastion-"
  vpc_id      = var.vpc_id

  # Only SSH on port 22 inbound allowed to bastions hosts (from everywhere)
  ingress {
    description = "SSH access from everywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ICMPv4 (ping) from everywhere
  ingress {
    description = "ICMPv4 from everywhere"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ICMPv6 from everywhere
  ingress {
    description      = "ICMPv6 from everywhere"
    from_port        = -1
    to_port          = -1
    protocol         = "icmpv6"
    ipv6_cidr_blocks = ["::/0"]
  }

  # All TCP Outbound
  egress {
    description = "All TCP outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.default_tags, {
    Name = format("sg-bastion-%s-%s-%s", var.region_short, var.environment, var.cell_name)
    type = "bastion-security-group"
  })
}

# Private Security Group (Private EC2)
resource "aws_security_group" "private" {
  name_prefix = "private-"
  vpc_id      = var.vpc_id

  # From bastions to private ec2 or subnets all allowed
  ingress {
    description     = "All traffic from bastion security group"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.bastion.id]
  }

  # All traffic from other cells in the same environment via TGW
  dynamic "ingress" {
    for_each = var.env_supernet_cidr != "" ? [var.env_supernet_cidr] : []
    content {
      description = "All traffic from same-environment cells via TGW"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = [ingress.value]
    }
  }

  # All TCP Outbound
  egress {
    description = "All TCP outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.default_tags, {
    Name = format("sg-private-%s-%s-%s", var.region_short, var.environment, var.cell_name)
    type = "private-security-group"
  })
}
