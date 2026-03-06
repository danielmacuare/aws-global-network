# security

Creates security groups for bastion and private EC2 instances and network ACLs for public and private subnets, with support for cross-cell and cross-region TGW traffic rules.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
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
| aws_security_group.bastion | resource |
| aws_security_group.private | resource |
| aws_network_acl.public | resource |
| aws_network_acl.private | resource |
| aws_network_acl_rule.public_inbound_ssh | resource |
| aws_network_acl_rule.public_inbound_http | resource |
| aws_network_acl_rule.public_inbound_https | resource |
| aws_network_acl_rule.public_inbound_icmp | resource |
| aws_network_acl_rule.public_inbound_icmpv6 | resource |
| aws_network_acl_rule.public_inbound_ephemeral | resource |
| aws_network_acl_rule.public_outbound_all | resource |
| aws_network_acl_rule.public_outbound_ipv6 | resource |
| aws_network_acl_rule.private_inbound_all | resource |
| aws_network_acl_rule.private_inbound_env_supernet | resource |
| aws_network_acl_rule.private_inbound_cross_region_supernet | resource |
| aws_network_acl_rule.private_inbound_cross_region_supernet_cidrs | resource |
| aws_network_acl_rule.private_outbound_all | resource |
| aws_network_acl_rule.private_outbound_ipv6 | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| vpc\_id | VPC ID where security groups will be created | `string` | n/a | yes |
| vpc\_cidr | VPC CIDR block for private security group rules | `string` | n/a | yes |
| default\_tags | Default tags to apply to all security group resources | `map(string)` | n/a | yes |
| region\_short | Short region code for naming | `string` | n/a | yes |
| environment | Environment name for naming | `string` | n/a | yes |
| public\_subnet\_ids | List of public subnet IDs | `list(string)` | n/a | yes |
| private\_subnet\_ids | List of private subnet IDs | `list(string)` | n/a | yes |
| cell\_name | Cell name for resource identification (e.g. cell1000) | `string` | n/a | yes |
| env\_supernet\_cidr | Environment-level supernet CIDR (e.g. 10.1.0.0/16 for euw2-dev) allowed to communicate with private instances across cells via TGW. | `string` | `""` | no |
| cross\_region\_supernet\_cidr | Peer-region environment supernet CIDR for cross-region prod-to-prod or dev-to-dev traffic via TGW peering (e.g. 10.0.0.0/16 for euw2-prod when deploying euw1-prod). | `string` | `""` | no |
| cross\_region\_supernet\_cidrs | List of peer-region environment supernet CIDRs for cross-region TGW peering traffic. Use when a cell peers with more than one remote region. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| bastion\_security\_group\_id | Security group ID for bastion instances |
| private\_security\_group\_id | Security group ID for private instances |
| public\_network\_acl\_id | Network ACL ID for public subnets |
| private\_network\_acl\_id | Network ACL ID for private subnets |
<!-- END_TF_DOCS -->
