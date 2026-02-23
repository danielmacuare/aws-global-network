## Tools

- Terraform

PROJECT_NAME=$HOME/repos/aws-global-network

## Build and test commands

terraform validate
terraform fmt --recursive $PROJECT_NAME
tflint --recursive --config=$PROJECT_NAME/tools/.tflint.hcl

## Code Style Guidelines

- Always run `terraform format --recursive` after changing a file.
- Indentation: White spaces with 2 spaces for indentation.
- For loops, use `for_each` instead of `count` when possible
- When creating resources in a module, use resource.this as a naming convention. Example: `resource "aws_vpc" "this"`
- Before adding new Terraform outputs or variables, check existing outputs/variables in the same module to avoid duplicates. Run `grep -r 'output "' <module_dir>/` before creating any new output blocks.

## Working with Terraform modules

- Always pin provider versions in a versions.tf file to prevent breaking changes when providers update.versions.tf
- Every variable must have a description and a type.
- Sensible Defaults: Only provide default values for variables that are truly optional; keep mandatory ones undefined to force explicit input.
- Consistent Outputs: Output the full resource objects or at least the IDs and ARNs so that the calling module has access to all necessary metadata.
- Use `sensitive = true` for variables that handle password or tokens.

## Terraform Resources Naming Convention

- We will use the following naming convention across this project for Name labels: `${resource_shortname}-${var.region_short}-${var.environment}-{optional_info}`
  - Example: sub-euw2-dev-priv-2 (Private Subnet)
  - Example: rt-euw2-dev-priv-2 (Private Ruting Table Subnet)

### Resource Shortnames

- NAT Gateways: ngw
- Subnets: sub
- Routing Table: rt

## NEVER DO THE FOLLOWING

- Never modify the backend configuration
- Never hardcode secrets.
