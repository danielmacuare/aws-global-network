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
  
  # All TCP Outbound
  egress {
    description = "All TCP outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(var.default_tags, {
    Name = format("sg-bastion-%s-%s", var.aws_region_short, var.environment)
    type = "bastion-security-group"
  })
}

# Private Security Group (Private EC2)
resource "aws_security_group" "private" {
  name_prefix = "private-"
  vpc_id      = var.vpc_id
  
  # From bastions to private ec2 or subnets all allowed
  ingress {
    description = "All traffic from bastion security group"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.bastion.id]
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
    Name = format("sg-private-%s-%s", var.aws_region_short, var.environment)
    type = "private-security-group"
  })
}
