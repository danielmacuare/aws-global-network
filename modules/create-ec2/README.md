# create-ec2

Creates bastion (public) and private EC2 instances within a VPC using Ubuntu 24.04 LTS, with configurable instance types, key pairs, and security groups.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >=1.1.7 |
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
| aws_instance.bastion | resource |
| aws_instance.private | resource |
| aws_ami.ubuntu_2404 | data source |
| aws_security_group.default | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| default\_tags | Default tags to apply to all resources | `map(string)` | n/a | yes |
| region | Target Region to deploy the resources | `string` | n/a | yes |
| region\_short | (Shorter Version) Target Region to deploy the resources. ie. use1, use2, euw2, etc | `string` | n/a | yes |
| environment | Target environment to deploy the resources. i.e prod, dev, stage, etc | `string` | n/a | yes |
| vpc\_name | Name of the VPC | `string` | n/a | yes |
| vpc\_id | VPC ID where EC2 instances will be created (needed to find default security group) | `string` | n/a | yes |
| public\_subnets | Map of public subnets for bastion instances | `map(any)` | n/a | yes |
| private\_subnets | Map of private subnets for private instances | `map(any)` | n/a | yes |
| key\_pair\_name | Name of the SSH key pair to use for EC2 instances | `string` | n/a | yes |
| cell\_name | Cell name to append to instance names for identification (e.g. cell1000) | `string` | n/a | yes |
| public\_security\_group\_id | Security group ID for bastion instances (uses VPC default if not provided) | `string` | `null` | no |
| private\_security\_group\_id | Security group ID for private instances (uses VPC default if not provided) | `string` | `null` | no |
| bastion\_instance\_type | Instance type for bastion hosts (t2.micro is free tier eligible) | `string` | `"t2.micro"` | no |
| private\_instance\_type | Instance type for private instances (t2.micro is free tier eligible) | `string` | `"t2.micro"` | no |

## Outputs

| Name | Description |
|------|-------------|
| bastion\_instances | Bastion EC2 instances |
| private\_instances | Private EC2 instances |
| bastion\_public\_ips | Public IPs of bastion instances |
| bastion\_private\_ips | Private IPs of bastion instances |
| private\_instance\_private\_ips | Private IPs of private instances |
| ubuntu\_ami\_id | Ubuntu 24.04 LTS AMI ID |
| ubuntu\_ami\_name | Ubuntu 24.04 LTS AMI name |
| bastion\_security\_group\_ids | Security group IDs used by bastion instances |
| private\_security\_group\_ids | Security group IDs used by private instances |
| default\_security\_group\_id | The VPC default security group ID |
<!-- END_TF_DOCS -->
