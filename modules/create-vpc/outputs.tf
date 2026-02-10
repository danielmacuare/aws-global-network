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
  description = "Private Route Tables"
  value       = aws_route_table.private
}

output "nat_gateway" {
  description = "Regional NAT Gateway"
  value       = awscc_ec2_nat_gateway.this
}
