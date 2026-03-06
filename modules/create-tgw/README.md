# create-tgw

Creates an AWS Transit Gateway with three dedicated route tables (prod, dev, wan) for segmented routing across environments and regions.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.1.7 |
| aws | >= 6.31.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 6.31.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| aws_ec2_transit_gateway.this | resource |
| aws_ec2_transit_gateway_route_table.prod | resource |
| aws_ec2_transit_gateway_route_table.dev | resource |
| aws_ec2_transit_gateway_route_table.wan | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| default\_tags | Standard project tags | `map(string)` | n/a | yes |
| region | Full AWS region name | `string` | n/a | yes |
| region\_short | Short region code (e.g., euw2) | `string` | n/a | yes |
| amazon\_side\_asn | BGP ASN for the Transit Gateway | `number` | n/a | yes |
| dns\_support | Enable DNS support for Transit Gateway | `string` | `"enable"` | no |
| vpn\_ecmp\_support | Enable ECMP support for VPN connections | `string` | `"disable"` | no |
| default\_route\_table\_association | Enable default route table association | `string` | `"disable"` | no |
| default\_route\_table\_propagation | Enable default route table propagation | `string` | `"disable"` | no |
| multicast\_support | Enable multicast support | `string` | `"disable"` | no |

## Outputs

| Name | Description |
|------|-------------|
| transit\_gateway | Full Transit Gateway resource object |
| route\_table\_prod | Production route table resource object |
| route\_table\_dev | Development route table resource object |
| route\_table\_wan | WAN route table for TGW peering attachments |
<!-- END_TF_DOCS -->
