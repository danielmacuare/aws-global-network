output "transit_gateway" {
  description = "Full Transit Gateway resource object"
  value       = aws_ec2_transit_gateway.this
}

output "route_table_prod" {
  description = "Production route table resource object"
  value       = aws_ec2_transit_gateway_route_table.prod
}

output "route_table_dev" {
  description = "Development route table resource object"
  value       = aws_ec2_transit_gateway_route_table.dev
}

output "route_table_shared" {
  description = "Shared services route table resource object"
  value       = aws_ec2_transit_gateway_route_table.shared
}
