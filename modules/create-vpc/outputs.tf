# ==============================================================================
# Full Resource Object Outputs
# ==============================================================================
# These outputs expose complete AWS resource objects with all attributes.
#
# Use case: Internal module consumption within the same Terraform root
# - Allows access to all resource attributes (e.g., vpc.cidr_block, subnet.availability_zone)
# - No need for terraform_remote_state
# - Ideal for rich, detailed consumption within the same environment
#
# Example usage:
#   module.vpc.vpc.id
#   module.vpc.private_subnets["subnet-a"].cidr_block
# ==============================================================================

output "vpc" {
  description = "VPC details including resource attributes, name, and environment"
  value = merge(
    { for k, v in aws_vpc.this : k => v },
    {
      name        = var.vpc_name
      environment = var.environment
    }
  )
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

# ==============================================================================
# Simplified Scalar Outputs
# ==============================================================================
# These outputs provide simple types (strings, lists) for easier consumption.
#
# Use case: Cross-environment access via terraform_remote_state
# - Simple to consume across state file boundaries
# - No need for complex for-loops in remote state consumers
# - Ideal for external modules or environments that need basic identifiers
#
# Example usage:
#   data.terraform_remote_state.vpc.outputs.vpc_id
#   data.terraform_remote_state.vpc.outputs.private_subnet_ids
# ==============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = [for k, v in aws_subnet.private : v.id]
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = [for k, v in aws_subnet.public : v.id]
}

