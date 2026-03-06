# create-key-pair

Generates an RSA 4096-bit TLS key pair, stores the private key locally as a PEM file, and registers the public key as an AWS key pair for use with EC2 instances.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >=1.1.7 |
| aws | >= 6.31.0 |
| tls | >= 4.0.0 |
| null | >= 3.0.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 6.31.0 |
| tls | >= 4.0.0 |
| null | >= 3.0.0 |
| local | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| tls_private_key.this | resource |
| null_resource.create_ssh_dir | resource |
| local_file.private_key | resource |
| aws_key_pair.this | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project\_root | Absolute path to project root where ssh-keys folder will be created | `string` | n/a | yes |
| region\_short | Short region code (euw2, use1, etc.) | `string` | n/a | yes |
| environment | Environment name (dev, prod, stage, etc.) | `string` | n/a | yes |
| default\_tags | Default tags to apply to resources | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| key\_pair\_name | The AWS key pair name |
| key\_pair\_arn | The AWS key pair ARN |
| key\_pair\_fingerprint | The AWS key pair fingerprint |
| private\_key\_path | Local path to the private key file |
<!-- END_TF_DOCS -->
