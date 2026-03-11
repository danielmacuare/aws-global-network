# ec2-test

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.2.1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.31.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 1.70.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.0.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_security"></a> [security](#module\_security) | ../../../modules/security | n/a |
| <a name="module_test_ec2"></a> [test\_ec2](#module\_test\_ec2) | ../../../modules/create-ec2 | n/a |
| <a name="module_test_key_pair"></a> [test\_key\_pair](#module\_test\_key\_pair) | ../../../modules/create-key-pair | n/a |
| <a name="module_test_vpc"></a> [test\_vpc](#module\_test\_vpc) | ../../../modules/create-vpc | n/a |

## Resources

No resources.

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bastion_instances"></a> [bastion\_instances](#output\_bastion\_instances) | Bastion EC2 instances |
| <a name="output_bastion_security_group_ids"></a> [bastion\_security\_group\_ids](#output\_bastion\_security\_group\_ids) | Security group IDs used by bastion instances |
| <a name="output_default_security_group_id"></a> [default\_security\_group\_id](#output\_default\_security\_group\_id) | VPC default security group ID |
| <a name="output_key_pair_arn"></a> [key\_pair\_arn](#output\_key\_pair\_arn) | The ARN of the created key pair |
| <a name="output_key_pair_name"></a> [key\_pair\_name](#output\_key\_pair\_name) | The name of the created key pair |
| <a name="output_private_instances"></a> [private\_instances](#output\_private\_instances) | Private EC2 instances |
| <a name="output_private_key_path"></a> [private\_key\_path](#output\_private\_key\_path) | Path to the saved private key |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID |
<!-- END_TF_DOCS -->
