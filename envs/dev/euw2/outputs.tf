output "vpc" {
  value = {
    "cidr_block" = module.vpc-main.vpc.cidr_block
    "id"         = module.vpc-main.vpc.id
  }
  description = "VPC output"
}

output "private_subnets_id" {
  value = {
    for subnet, attribute in module.vpc-main.private_subnets : subnet => {
      id        = attribute["id"]
      cidr_ipv4 = attribute["cidr_block"]
      cidr_ipv6 = attribute["ipv6_cidr_block"]
    }
  }
  description = "Private Subnets' ID and CIDR blocks"
}

output "public_subnets_id" {
  value = {
    for subnet, attribute in module.vpc-main.public_subnets : subnet => {
      id        = attribute["id"]
      cidr_ipv4 = attribute["cidr_block"]
      cidr_ipv6 = attribute["ipv6_cidr_block"]
    }
  }
  description = "Public Subnets' ID and CIDR blocks"
}

output "private_route_tables_id" {
  value       = { for route-table, attribute in module.vpc-main.private_route_tables : route-table => attribute["id"] }
  description = "Private Route Tables' ID"
}

output "nat_gateway_id" {
  value       = module.vpc-main.nat_gateway.nat_gateway_id
  description = "Regional NAT Gateway ID"
}