output "bastion_security_group_id" {
  description = "Security group ID for bastion instances"
  value       = aws_security_group.bastion.id
}

output "private_security_group_id" {
  description = "Security group ID for private instances"
  value       = aws_security_group.private.id
}

output "public_network_acl_id" {
  description = "Network ACL ID for public subnets"
  value       = aws_network_acl.public.id
}

output "private_network_acl_id" {
  description = "Network ACL ID for private subnets"
  value       = aws_network_acl.private.id
}
