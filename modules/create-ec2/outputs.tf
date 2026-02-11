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
