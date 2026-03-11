# cell6001

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.4 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.31.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 1.70.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.0.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.35.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ec2"></a> [ec2](#module\_ec2) | ../../../../modules/create-ec2 | n/a |
| <a name="module_security"></a> [security](#module\_security) | ../../../../modules/security | n/a |
| <a name="module_vpc-main"></a> [vpc-main](#module\_vpc-main) | ../../../../modules/create-vpc/ | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_key_pair.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/key_pair) | data source |

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_instances"></a> [instances](#output\_instances) | EC2 instance names and their IPs for SSH access |
| <a name="output_nat_gateway_id"></a> [nat\_gateway\_id](#output\_nat\_gateway\_id) | Regional NAT Gateway ID |
| <a name="output_private_route_tables_id"></a> [private\_route\_tables\_id](#output\_private\_route\_tables\_id) | Private Route Tables' ID |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | List of private subnet IDs (convenience output for remote state) |
| <a name="output_private_subnets_id"></a> [private\_subnets\_id](#output\_private\_subnets\_id) | Private Subnets' ID and CIDR blocks |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | List of public subnet IDs (convenience output for remote state) |
| <a name="output_public_subnets_id"></a> [public\_subnets\_id](#output\_public\_subnets\_id) | Public Subnets' ID and CIDR blocks |
| <a name="output_ssh_key_path"></a> [ssh\_key\_path](#output\_ssh\_key\_path) | Local path to the SSH private key for this cell |
| <a name="output_vpc"></a> [vpc](#output\_vpc) | VPC output with all attributes including id, cidr\_block, name, and environment |
<!-- END_TF_DOCS -->
