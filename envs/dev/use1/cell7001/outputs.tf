output "vpc" {
  value       = module.vpc-main.vpc
  description = "VPC output with all attributes including id, cidr_block, name, and environment"
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

output "private_subnet_ids" {
  value       = module.vpc-main.private_subnet_ids
  description = "List of private subnet IDs (convenience output for remote state)"
}

output "public_subnet_ids" {
  value       = module.vpc-main.public_subnet_ids
  description = "List of public subnet IDs (convenience output for remote state)"
}

output "instances" {
  description = "EC2 instance names and their IPs for SSH access"
  value = {
    bastions = {
      for k, ip in module.ec2.bastion_public_ips :
      format("bastion-%s-%s-%s-%s", local.region_short, local.environment, k, local.cell_name) => ip
    }
    private_hosts = {
      for k, ip in module.ec2.private_instance_private_ips :
      format("private-%s-%s-%s-%s", local.region_short, local.environment, k, local.cell_name) => ip
    }
  }
}

output "ssh_key_path" {
  description = "Local path to the SSH private key for this cell"
  value       = "${local.project_root}/ssh-keys/${local.region_short}-${local.environment}.pem"
}
