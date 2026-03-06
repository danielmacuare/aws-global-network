# create-vpc

Creates a fully-featured VPC with public and private subnets across availability zones, an internet gateway, a regional NAT gateway (auto mode), an IPv6 egress-only gateway, and all associated route tables and routes.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >=1.1.7 |
| aws | >= 6.31.0 |
| awscc | >= 1.70.0 |
| time | >= 0.9.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 6.31.0 |
| awscc | >= 1.70.0 |
| time | >= 0.9.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| aws_vpc.this | resource |
| aws_egress_only_internet_gateway.this | resource |
| aws_subnet.private | resource |
| aws_subnet.public | resource |
| aws_internet_gateway.this | resource |
| time_sleep.wait_for_vpc | resource |
| awscc_ec2_nat_gateway.this | resource |
| aws_route_table.private | resource |
| aws_route_table_association.private | resource |
| aws_route.private_ipv4_default | resource |
| aws_route_table.public | resource |
| aws_route_table_association.public | resource |
| aws_route.public_ipv4_default | resource |
| aws_route.public_ipv6_default | resource |
| aws_route.private_ipv6_egress | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| default\_tags | Default tags to apply to all resources | `map(string)` | n/a | yes |
| region | Target Region to deploy the resources | `string` | n/a | yes |
| region\_short | (Shorter Version) Target Region to deploy the resources. ie. use1, use2, euw2, etc | `string` | n/a | yes |
| environment | Target environment to deploy the resources. i.e prod, dev, stage, etc | `string` | n/a | yes |
| vpc\_name | Name of the VPC | `string` | n/a | yes |
| cell\_name | Cell name for resource identification (e.g. cell1000) | `string` | n/a | yes |
| vpc\_cidr | CIDR for the VPC | `string` | n/a | yes |
| private\_subnets | Map including private subnets, their AZs and their CIDRs | `map(map(string))` | n/a | yes |
| public\_subnets | Map including public subnets, their AZs and their CIDRs | `map(map(string))` | n/a | yes |
| assign\_generated\_ipv6\_cidr\_block | Requests an Amazon-provided IPv6 CIDR block with a /56 prefix length for the VPC. You cannot specify the range of IP addresses, or the size of the CIDR block | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc | VPC details including resource attributes, name, and environment |
| private\_subnets | Private Subnets |
| public\_subnets | Public Subnets |
| private\_route\_tables | Private Route Tables |
| nat\_gateway | Regional NAT Gateway |
| vpc\_id | VPC ID |
| private\_subnet\_ids | List of private subnet IDs |
| public\_subnet\_ids | List of public subnet IDs |
<!-- END_TF_DOCS -->
