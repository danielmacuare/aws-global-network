# create-tgw-vpc-attachment

Attaches a VPC to an AWS Transit Gateway, associates and propagates the attachment into the appropriate route tables, and adds VPC-side supernet routes to enable east-west traffic across cells and regions.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.1.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.31.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.35.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_ec2_transit_gateway_route_table_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table_association) | resource |
| [aws_ec2_transit_gateway_route_table_propagation.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table_propagation) | resource |
| [aws_ec2_transit_gateway_route_table_propagation.wan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table_propagation) | resource |
| [aws_ec2_transit_gateway_vpc_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_vpc_attachment) | resource |
| [aws_route.tgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_appliance_mode_support"></a> [appliance\_mode\_support](#input\_appliance\_mode\_support) | Enable appliance mode support for the attachment | `string` | `"disable"` | no |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | Standard project tags | `map(string)` | n/a | yes |
| <a name="input_dns_support"></a> [dns\_support](#input\_dns\_support) | Enable DNS support for the attachment | `string` | `"enable"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (dev, prod, shared) | `string` | n/a | yes |
| <a name="input_private_route_table_ids"></a> [private\_route\_table\_ids](#input\_private\_route\_table\_ids) | Map of private route table IDs (key → rtb-id) to add a TGW supernet route to. Required for VPC instances to send east-west traffic through the TGW. | `map(string)` | `{}` | no |
| <a name="input_region_short"></a> [region\_short](#input\_region\_short) | Short region code (e.g., euw2) | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnet IDs for the attachment (one per AZ) | `list(string)` | n/a | yes |
| <a name="input_tgw_supernet_cidr"></a> [tgw\_supernet\_cidr](#input\_tgw\_supernet\_cidr) | Supernet CIDR routed to the TGW from each private subnet route table (e.g. 10.0.0.0/8 covers all cells across all regions). | `string` | `"10.0.0.0/8"` | no |
| <a name="input_transit_gateway_id"></a> [transit\_gateway\_id](#input\_transit\_gateway\_id) | Transit Gateway ID to attach to | `string` | n/a | yes |
| <a name="input_transit_gateway_route_table_id"></a> [transit\_gateway\_route\_table\_id](#input\_transit\_gateway\_route\_table\_id) | Transit Gateway route table ID to associate with | `string` | n/a | yes |
| <a name="input_transit_gateway_wan_route_table_id"></a> [transit\_gateway\_wan\_route\_table\_id](#input\_transit\_gateway\_wan\_route\_table\_id) | WAN route table ID to also propagate this attachment into. Required for inbound cross-region delivery via TGW peering. Leave null if peering is not used. | `string` | `null` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID to attach | `string` | n/a | yes |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | Name of the VPC for attachment naming | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_attachment_id"></a> [attachment\_id](#output\_attachment\_id) | VPC attachment ID |
| <a name="output_vpc_attachment"></a> [vpc\_attachment](#output\_vpc\_attachment) | Full VPC attachment resource object |
<!-- END_TF_DOCS -->
