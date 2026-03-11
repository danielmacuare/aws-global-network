# tgw

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.4 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.31.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_tgw"></a> [tgw](#module\_tgw) | ../../../../modules/create-tgw | n/a |

## Resources

No resources.

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_route_table_dev"></a> [route\_table\_dev](#output\_route\_table\_dev) | Development route table |
| <a name="output_route_table_prod"></a> [route\_table\_prod](#output\_route\_table\_prod) | Production route table |
| <a name="output_route_table_wan"></a> [route\_table\_wan](#output\_route\_table\_wan) | WAN route table for TGW peering attachments |
| <a name="output_transit_gateway"></a> [transit\_gateway](#output\_transit\_gateway) | Transit Gateway resource |
<!-- END_TF_DOCS -->
