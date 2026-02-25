output "transit_gateway" {
  description = "Transit Gateway resource"
  value       = module.tgw.transit_gateway
}

output "route_table_prod" {
  description = "Production route table"
  value       = module.tgw.route_table_prod
}

output "route_table_dev" {
  description = "Development route table"
  value       = module.tgw.route_table_dev
}

output "route_table_shared" {
  description = "Shared services route table"
  value       = module.tgw.route_table_shared
}
