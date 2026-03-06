# create-vpc

Creates a fully-featured VPC with public and private subnets across availability zones, an internet gateway, a regional NAT gateway (auto mode), an IPv6 egress-only gateway, and all associated route tables and routes.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.1.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.31.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 1.70.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.31.0 |
| <a name="provider_awscc"></a> [awscc](#provider\_awscc) | 1.70.0 |
| <a name="provider_time"></a> [time](#provider\_time) | >= 0.9.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_egress_only_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/egress_only_internet_gateway) | resource |
| [aws_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_route.private_ipv4_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.private_ipv6_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_ipv4_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_ipv6_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [awscc_ec2_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/ec2_nat_gateway) | resource |
| [time_sleep.wait_for_vpc](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_assign_generated_ipv6_cidr_block"></a> [assign\_generated\_ipv6\_cidr\_block](#input\_assign\_generated\_ipv6\_cidr\_block) | Requests an Amazon-provided IPv6 CIDR block with a /56 prefix length for the VPC. You cannot specify the range of IP addresses, or the size of the CIDR block | `bool` | `false` | no |
| <a name="input_cell_name"></a> [cell\_name](#input\_cell\_name) | Cell name for resource identification (e.g. cell1000) | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | Default tags to apply to all resources | `map(string)` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Target environment to deploy the resources. i.e prod, dev, stage, etc | `string` | n/a | yes |
| <a name="input_private_subnets"></a> [private\_subnets](#input\_private\_subnets) | Map including private subnets, their AZs and their CIDRs | `map(map(string))` | n/a | yes |
| <a name="input_public_subnets"></a> [public\_subnets](#input\_public\_subnets) | Map including public subnets, their AZs and their CIDRs | `map(map(string))` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Target Region to deploy the resources | `string` | n/a | yes |
| <a name="input_region_short"></a> [region\_short](#input\_region\_short) | (Shorter Version) Target Region to deploy the resources. ie. use1, use2, euw2, etc | `string` | n/a | yes |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR for the VPC | `string` | n/a | yes |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | Name of the VPC | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_nat_gateway"></a> [nat\_gateway](#output\_nat\_gateway) | Regional NAT Gateway |
| <a name="output_private_route_tables"></a> [private\_route\_tables](#output\_private\_route\_tables) | Private Route Tables |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | List of private subnet IDs |
| <a name="output_private_subnets"></a> [private\_subnets](#output\_private\_subnets) | Private Subnets |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | List of public subnet IDs |
| <a name="output_public_subnets"></a> [public\_subnets](#output\_public\_subnets) | Public Subnets |
| <a name="output_vpc"></a> [vpc](#output\_vpc) | VPC details including resource attributes, name, and environment |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID |
<!-- END_TF_DOCS -->
