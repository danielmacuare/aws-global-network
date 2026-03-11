# create-key-pair

Generates an RSA 4096-bit TLS key pair, stores the private key locally as a PEM file, and registers the public key as an AWS key pair for use with EC2 instances.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.4 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.31.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.0.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.35.1 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.7.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.2.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_key_pair.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair) | resource |
| [local_file.private_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.create_ssh_dir](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [tls_private_key.this](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | Default tags to apply to resources | `map(string)` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (dev, prod, stage, etc.) | `string` | n/a | yes |
| <a name="input_project_root"></a> [project\_root](#input\_project\_root) | Absolute path to project root where ssh-keys folder will be created | `string` | n/a | yes |
| <a name="input_region_short"></a> [region\_short](#input\_region\_short) | Short region code (euw2, use1, etc.) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_key_pair_arn"></a> [key\_pair\_arn](#output\_key\_pair\_arn) | The AWS key pair ARN |
| <a name="output_key_pair_fingerprint"></a> [key\_pair\_fingerprint](#output\_key\_pair\_fingerprint) | The AWS key pair fingerprint |
| <a name="output_key_pair_name"></a> [key\_pair\_name](#output\_key\_pair\_name) | The AWS key pair name |
| <a name="output_private_key_path"></a> [private\_key\_path](#output\_private\_key\_path) | Local path to the private key file |
<!-- END_TF_DOCS -->
