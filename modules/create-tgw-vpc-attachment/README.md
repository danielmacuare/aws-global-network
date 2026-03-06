# create-tgw-vpc-attachment

Attaches a VPC to an AWS Transit Gateway, associates and propagates the attachment into the appropriate route tables, and adds VPC-side supernet routes to enable east-west traffic across cells and regions.

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
| aws_ec2_transit_gateway_vpc_attachment.this | resource |
| aws_ec2_transit_gateway_route_table_association.this | resource |
| aws_ec2_transit_gateway_route_table_propagation.this | resource |
| aws_ec2_transit_gateway_route_table_propagation.wan | resource |
| aws_route.tgw | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| default\_tags | Standard project tags | `map(string)` | n/a | yes |
| transit\_gateway\_id | Transit Gateway ID to attach to | `string` | n/a | yes |
| vpc\_id | VPC ID to attach | `string` | n/a | yes |
| subnet\_ids | Subnet IDs for the attachment (one per AZ) | `list(string)` | n/a | yes |
| transit\_gateway\_route\_table\_id | Transit Gateway route table ID to associate with | `string` | n/a | yes |
| environment | Environment name (dev, prod, shared) | `string` | n/a | yes |
| region\_short | Short region code (e.g., euw2) | `string` | n/a | yes |
| vpc\_name | Name of the VPC for attachment naming | `string` | n/a | yes |
| dns\_support | Enable DNS support for the attachment | `string` | `"enable"` | no |
| appliance\_mode\_support | Enable appliance mode support for the attachment | `string` | `"disable"` | no |
| private\_route\_table\_ids | Map of private route table IDs (key → rtb-id) to add a TGW supernet route to. Required for VPC instances to send east-west traffic through the TGW. | `map(string)` | `{}` | no |
| tgw\_supernet\_cidr | Supernet CIDR routed to the TGW from each private subnet route table (e.g. 10.0.0.0/8 covers all cells across all regions). | `string` | `"10.0.0.0/8"` | no |
| transit\_gateway\_wan\_route\_table\_id | WAN route table ID to also propagate this attachment into. Required for inbound cross-region delivery via TGW peering. Leave null if peering is not used. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc\_attachment | Full VPC attachment resource object |
| attachment\_id | VPC attachment ID |
<!-- END_TF_DOCS -->
