# ==============================================================================
# Complex Object Outputs
# ==============================================================================
# These outputs provide structured objects with multiple attributes per resource.
#
# Use case: Internal consumption within this environment (envs/dev/euw2/cell1001/)
# - Used by ec2s.tf and security.tf for rich attribute access
# - Provides full context (IDs, CIDR blocks, name, environment) in a single output
# - Ideal when consumers need multiple attributes from the same resource
#
# Example internal usage:
#   module.vpc-main.vpc.id
#   module.vpc-main.vpc.cidr_block
#   module.vpc-main.vpc.name
#   module.vpc-main.vpc.environment
# ==============================================================================

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

# ==============================================================================
# Simplified Scalar Outputs
# ==============================================================================
# These outputs provide simple types (strings, lists) for cross-environment access.
#
# Use case: Remote state consumption by other environments (e.g., TGW attachments)
# - Used by envs/networking/euw2/tgw-vpc-atts/ via terraform_remote_state
# - Eliminates need for complex for-loops in remote consumers
# - Provides clean, simple interface for cross-boundary consumption
#
# Example remote usage:
#   data.terraform_remote_state.dev_vpc.outputs.vpc.id
#   data.terraform_remote_state.dev_vpc.outputs.vpc.name
#   data.terraform_remote_state.dev_vpc.outputs.vpc.environment
#   data.terraform_remote_state.dev_vpc.outputs.private_subnet_ids
# ==============================================================================

output "private_subnet_ids" {
  value       = module.vpc-main.private_subnet_ids
  description = "List of private subnet IDs (convenience output for remote state)"
}

output "public_subnet_ids" {
  value       = module.vpc-main.public_subnet_ids
  description = "List of public subnet IDs (convenience output for remote state)"
}

# ==============================================================================
# Instance Inventory Outputs
# ==============================================================================
# Used by scripts/deploy.sh after deployment to display SSH access details.
# ==============================================================================

output "instances" {
  description = "EC2 instance names and their IPs for SSH access"
  value = {
    bastions = {
      for k, ip in module.ec2.bastion_public_ips :
      format("bastion-%s-%s-%s", local.region_short, local.environment, k) => ip
    }
    private_hosts = {
      for k, ip in module.ec2.private_instance_private_ips :
      format("private-%s-%s-%s", local.region_short, local.environment, k) => ip
    }
  }
}

output "ssh_key_path" {
  description = "Local path to the SSH private key for this cell"
  value       = "${local.project_root}/ssh-keys/${local.region_short}-${local.environment}.pem"
}
