# create-tgw

Creates an AWS Transit Gateway with three dedicated route tables (prod, dev, wan) for segmented routing across environments and regions.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.4 |
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
| [aws_ec2_transit_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway) | resource |
| [aws_ec2_transit_gateway_route_table.dev](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table) | resource |
| [aws_ec2_transit_gateway_route_table.prod](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table) | resource |
| [aws_ec2_transit_gateway_route_table.wan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_amazon_side_asn"></a> [amazon\_side\_asn](#input\_amazon\_side\_asn) | BGP ASN for the Transit Gateway | `number` | n/a | yes |
| <a name="input_default_route_table_association"></a> [default\_route\_table\_association](#input\_default\_route\_table\_association) | Enable default route table association | `string` | `"disable"` | no |
| <a name="input_default_route_table_propagation"></a> [default\_route\_table\_propagation](#input\_default\_route\_table\_propagation) | Enable default route table propagation | `string` | `"disable"` | no |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | Standard project tags | `map(string)` | n/a | yes |
| <a name="input_dns_support"></a> [dns\_support](#input\_dns\_support) | Enable DNS support for Transit Gateway | `string` | `"enable"` | no |
| <a name="input_multicast_support"></a> [multicast\_support](#input\_multicast\_support) | Enable multicast support | `string` | `"disable"` | no |
| <a name="input_region"></a> [region](#input\_region) | Full AWS region name | `string` | n/a | yes |
| <a name="input_region_short"></a> [region\_short](#input\_region\_short) | Short region code (e.g., euw2) | `string` | n/a | yes |
| <a name="input_vpn_ecmp_support"></a> [vpn\_ecmp\_support](#input\_vpn\_ecmp\_support) | Enable ECMP support for VPN connections | `string` | `"disable"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_route_table_dev"></a> [route\_table\_dev](#output\_route\_table\_dev) | Development route table resource object |
| <a name="output_route_table_prod"></a> [route\_table\_prod](#output\_route\_table\_prod) | Production route table resource object |
| <a name="output_route_table_wan"></a> [route\_table\_wan](#output\_route\_table\_wan) | WAN route table for TGW peering attachments |
| <a name="output_transit_gateway"></a> [transit\_gateway](#output\_transit\_gateway) | Full Transit Gateway resource object |
<!-- END_TF_DOCS -->
