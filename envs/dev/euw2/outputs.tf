output "vpc" {
  value = {
    "cidr_block" = module.vpc-main.vpc.cidr_block
    "id"         = module.vpc-main.vpc.id
  }
  description = "VPC output"
}

output "private_subnets_id" {
  value       = { for subnet, attribute in module.vpc-main.private_subnets : subnet => attribute["id"] }
  description = "Private Subnets' ID"
}

output "public_subnets_id" {
  value       = { for subnet, attribute in module.vpc-main.public_subnets : subnet => attribute["id"] }
  description = "Public Subnets' ID"
}

output "private_route_tables_id" {
  value       = { for route-table, attribute in module.vpc-main.private_route_tables : route-table => attribute["id"] }
  description = "Private Route Tables' ID"
}