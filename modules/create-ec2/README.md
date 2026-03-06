# create-ec2

Creates bastion (public) and private EC2 instances within a VPC using Ubuntu 24.04 LTS, with configurable instance types, key pairs, and security groups.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.1.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.31.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.31.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_instance.bastion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_instance.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_ami.ubuntu_2404](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_security_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_group) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bastion_instance_type"></a> [bastion\_instance\_type](#input\_bastion\_instance\_type) | Instance type for bastion hosts (t2.micro is free tier eligible) | `string` | `"t2.micro"` | no |
| <a name="input_cell_name"></a> [cell\_name](#input\_cell\_name) | Cell name to append to instance names for identification (e.g. cell1000) | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | Default tags to apply to all resources | `map(string)` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Target environment to deploy the resources. i.e prod, dev, stage, etc | `string` | n/a | yes |
| <a name="input_key_pair_name"></a> [key\_pair\_name](#input\_key\_pair\_name) | Name of the SSH key pair to use for EC2 instances | `string` | n/a | yes |
| <a name="input_private_instance_type"></a> [private\_instance\_type](#input\_private\_instance\_type) | Instance type for private instances (t2.micro is free tier eligible) | `string` | `"t2.micro"` | no |
| <a name="input_private_security_group_id"></a> [private\_security\_group\_id](#input\_private\_security\_group\_id) | Security group ID for private instances (uses VPC default if not provided) | `string` | `null` | no |
| <a name="input_private_subnets"></a> [private\_subnets](#input\_private\_subnets) | Map of private subnets for private instances | `map(any)` | n/a | yes |
| <a name="input_public_security_group_id"></a> [public\_security\_group\_id](#input\_public\_security\_group\_id) | Security group ID for bastion instances (uses VPC default if not provided) | `string` | `null` | no |
| <a name="input_public_subnets"></a> [public\_subnets](#input\_public\_subnets) | Map of public subnets for bastion instances | `map(any)` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Target Region to deploy the resources | `string` | n/a | yes |
| <a name="input_region_short"></a> [region\_short](#input\_region\_short) | (Shorter Version) Target Region to deploy the resources. ie. use1, use2, euw2, etc | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where EC2 instances will be created (needed to find default security group) | `string` | n/a | yes |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | Name of the VPC | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bastion_instances"></a> [bastion\_instances](#output\_bastion\_instances) | Bastion EC2 instances |
| <a name="output_bastion_private_ips"></a> [bastion\_private\_ips](#output\_bastion\_private\_ips) | Private IPs of bastion instances |
| <a name="output_bastion_public_ips"></a> [bastion\_public\_ips](#output\_bastion\_public\_ips) | Public IPs of bastion instances |
| <a name="output_bastion_security_group_ids"></a> [bastion\_security\_group\_ids](#output\_bastion\_security\_group\_ids) | Security group IDs used by bastion instances |
| <a name="output_default_security_group_id"></a> [default\_security\_group\_id](#output\_default\_security\_group\_id) | The VPC default security group ID |
| <a name="output_private_instance_private_ips"></a> [private\_instance\_private\_ips](#output\_private\_instance\_private\_ips) | Private IPs of private instances |
| <a name="output_private_instances"></a> [private\_instances](#output\_private\_instances) | Private EC2 instances |
| <a name="output_private_security_group_ids"></a> [private\_security\_group\_ids](#output\_private\_security\_group\_ids) | Security group IDs used by private instances |
| <a name="output_ubuntu_ami_id"></a> [ubuntu\_ami\_id](#output\_ubuntu\_ami\_id) | Ubuntu 24.04 LTS AMI ID |
| <a name="output_ubuntu_ami_name"></a> [ubuntu\_ami\_name](#output\_ubuntu\_ami\_name) | Ubuntu 24.04 LTS AMI name |
<!-- END_TF_DOCS -->
