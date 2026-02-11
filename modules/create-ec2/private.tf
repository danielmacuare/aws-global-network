resource "aws_instance" "private" {
  for_each = var.private_subnets

  ami           = data.aws_ami.ubuntu_2404.id
  instance_type = var.private_instance_type
  subnet_id     = each.value.id
  # Ternary operator: If a custom security group ID is provided, use it. Otherwise, fall back to the VPC's default security group.
  vpc_security_group_ids      = var.private_security_group_id != null ? [var.private_security_group_id] : [data.aws_security_group.default.id]
  key_name                    = var.key_pair_name
  associate_public_ip_address = false

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = merge(
    var.default_tags,
    {
      Name = format("private-%s-%s-%s", var.aws_region_short, var.environment, each.key)
      type = "application"
    }
  )
}
