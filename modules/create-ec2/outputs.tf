output "bastion_instances" {
  description = "Bastion EC2 instances"
  value       = aws_instance.bastion
}

output "private_instances" {
  description = "Private EC2 instances"
  value       = aws_instance.private
}

output "bastion_public_ips" {
  description = "Public IPs of bastion instances"
  value       = { for k, v in aws_instance.bastion : k => v.public_ip }
}

output "bastion_private_ips" {
  description = "Private IPs of bastion instances"
  value       = { for k, v in aws_instance.bastion : k => v.private_ip }
}

output "private_instance_private_ips" {
  description = "Private IPs of private instances"
  value       = { for k, v in aws_instance.private : k => v.private_ip }
}

output "ubuntu_ami_id" {
  description = "Ubuntu 24.04 LTS AMI ID"
  value       = data.aws_ami.ubuntu_2404.id
}

output "ubuntu_ami_name" {
  description = "Ubuntu 24.04 LTS AMI name"
  value       = data.aws_ami.ubuntu_2404.name
}

output "bastion_security_group_ids" {
  description = "Security group IDs used by bastion instances"
  # Ternary operator: Return custom security group ID if provided, otherwise return VPC default security group ID
  value = var.public_security_group_id != null ? [var.public_security_group_id] : [data.aws_security_group.default.id]
}

output "private_security_group_ids" {
  description = "Security group IDs used by private instances"
  # Ternary operator: Return custom security group ID if provided, otherwise return VPC default security group ID
  value = var.private_security_group_id != null ? [var.private_security_group_id] : [data.aws_security_group.default.id]
}

output "default_security_group_id" {
  description = "The VPC default security group ID"
  value       = data.aws_security_group.default.id
}
