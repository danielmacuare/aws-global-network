output "vpc" {
  description = "VPC"
  value       = aws_vpc.this
}

output "private_subnets" {
  description = "Private Subnets"
  value       = aws_subnet.private
}

output "public_subnets" {
  description = "Public Subnets"
  value       = aws_subnet.public
}

output "private_route_tables" {
  description = "List of IDs of public subnets."
  value       = aws_route_table.private
}
