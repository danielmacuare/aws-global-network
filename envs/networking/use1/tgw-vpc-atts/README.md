# tgw-vpc-atts

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.2.1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.31.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_vpc_attachments"></a> [vpc\_attachments](#module\_vpc\_attachments) | ../../../../modules/create-tgw-vpc-attachment | n/a |

## Resources

| Name | Type |
|------|------|
| [terraform_remote_state.tgw](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |
| [terraform_remote_state.vpc_states](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_backend_bucket"></a> [backend\_bucket](#input\_backend\_bucket) | S3 bucket name for Terraform remote state | `string` | `"dmac-bootstrap-tfstate"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_attachment_count"></a> [attachment\_count](#output\_attachment\_count) | Number of VPC attachments created |
| <a name="output_attachment_ids"></a> [attachment\_ids](#output\_attachment\_ids) | VPC attachment IDs for all cells |
| <a name="output_vpc_attachments"></a> [vpc\_attachments](#output\_vpc\_attachments) | VPC attachment details for all cells |
<!-- END_TF_DOCS -->
