
## Diagram
![Diagram](../resources/tgw-multi-region.png)


## Considerations
- Traffic between the Prod and Dev environments will be isolated by using different Transit Gateway Routing Tables.
- All the resources in this deployment belong to a single AWS account.
- This repo is not intended to be used in a production environment but to help testing and understanding how to build a global network infrastructure with AWS.
- By default, an AWS account is limited to 5 Elastic IPs per region. For this reasons, we only have configured one NGW in each VPC in each region. The NGW will be configured in the public-subnet-1 on each VPC/Cell. In production, you can use one NGW per each public subnets for maximum redundancy.
- This repo has been deployed with an IAM user and a policy that provides admin access. In a production environment, you'd want to grant the least privilege for users to deploy their resources.


## Regions


## IP Allocation

The allocation follows a hierarchical structure:
- Each region gets a /12 block
- Within each region, Prod gets one /16 and Dev gets another /16
- Each VPC (cell) gets a /20 from its environment's /16 block
- This provides room for 16 VPCs per environment per region (16 × /20 = /16)

| VPC Name | Environment | VPC CIDR | Region/Env Summary | Region |
|----------|-------------|----------|-------------------|---------|
| vpc-euw2-prod-cell0000 | Prod | 10.0.0.0/20 | 10.0.0.0/16 | eu-west-2 - London |
| vpc-euw2-prod-cell0001 | Prod | 10.0.16.0/20 | | |
| vpc-euw2-dev-cell1000 | Dev | 10.1.0.0/20 | 10.1.0.0/16 | |
| vpc-euw2-dev-cell1001 | Dev | 10.1.16.0/20 | | |
| vpc-euw1-prod-cell2000 | Prod | 10.16.0.0/20 | 10.16.0.0/16 | eu-west-1 - Ireland |
| vpc-euw1-prod-cell2001 | Prod | 10.16.16.0/20 | | |
| vpc-euw1-dev-cell3000 | Dev | 10.17.0.0/20 | 10.17.0.0/16 | |
| vpc-euw1-dev-cell3001 | Dev | 10.17.16.0/20 | | |
| vpc-usw2-prod-cell4000 | Prod | 10.32.0.0/20 | 10.32.0.0/16 | us-west-2 - Oregon |
| vpc-usw2-prod-cell4001 | Prod | 10.32.16.0/20 | | |
| vpc-usw2-dev-cell5000 | Dev | 10.33.0.0/20 | 10.33.0.0/16 | |
| vpc-usw2-dev-cell5001 | Dev | 10.33.16.0/20 | | |
| vpc-usw1-prod-cell6000 | Prod | 10.48.0.0/20 | 10.48.0.0/16 | us-west-1 - N California |
| vpc-usw1-prod-cell6001 | Prod | 10.48.16.0/20 | | |
| vpc-usw1-dev-cell7000 | Dev | 10.49.0.0/20 | 10.49.0.0/16 | |
| vpc-usw1-dev-cell7001 | Dev | 10.49.16.0/20 | | |

## Transit Gateway

### ASNs

euw2: 64514
euw1: 64515
usw1: 64517
usw2: 64518


### TGW Route Tables
- 3 Route Tables per TGW: prod, dev, and wan.
    - Prod can't communicate with Dev and the other way around.
    - WAN is dedicated to TGW peering attachments (cross-region links).
    - VPCs tagged with environment = dev will be attached to the dev routing table.
    - VPCs tagged with environment = prod will be attached to the prod routing table.
    - TGW peering attachments are associated with the wan routing table.

### Cross-Region Routing
- TGW peering attachments do not support route propagation — static routes are required.
- Each region's prod, dev, and wan route tables have a static route pointing the remote region's /12 supernet through the peering attachment.
- Prod-to-prod and dev-to-dev cross-region traffic is enabled. Prod-to-dev isolation is enforced by the VPC attachment associations (prod VPCs on the prod route table, dev VPCs on the dev route table).



## Naming Convention

All AWS resources follow a consistent naming pattern for the `Name` tag to enable easy identification in the AWS Console, especially when multiple cells coexist in the same region.

### General Pattern

```
{resource_shortname}-{region_short}-{environment}-{optional_info}-{cell_name}
```

- `resource_shortname`: Short identifier for the resource type (see tables below)
- `region_short`: AWS region short code (euw2, euw1, usw2, etc.)
- `environment`: Environment name (prod, dev)
- `optional_info`: Context-specific info like subnet key (pub-0, priv-1, etc.)
- `cell_name`: The cell identifier (cell0000, cell1000, etc.)

### Cell-Scoped Resources

These resources belong to a specific VPC/cell and include `cell_name` in their Name tag:

| Resource | Shortname | Name Pattern | Example |
|----------|-----------|-------------|---------|
| VPC | vpc | `vpc-{region_short}-{env}-{cell}` | vpc-euw2-prod-cell0000 |
| Internet Gateway | igw | `igw-{region_short}-{env}-{cell}` | igw-euw2-dev-cell1000 |
| Egress-only IPv6 IGW | egipv6-igw | `egipv6-igw-{region_short}-{env}-{cell}` | egipv6-igw-euw2-dev-cell1000 |
| NAT Gateway | ngw | `ngw-{region_short}-{env}-{cell}` | ngw-euw2-prod-cell0000 |
| Subnet | sub | `sub-{region_short}-{env}-{subnet_key}-{cell}` | sub-euw2-dev-priv-2-cell1000 |
| Route Table | rtb | `rtb-{region_short}-{env}-{subnet_key}-{cell}` | rtb-euw2-dev-priv-2-cell1000 |
| Bastion EC2 | bastion | `bastion-{region_short}-{env}-{subnet_key}-{cell}` | bastion-euw2-prod-pub-0-cell0000 |
| Private EC2 | private | `private-{region_short}-{env}-{subnet_key}-{cell}` | private-euw2-prod-priv-1-cell0000 |
| Bastion Security Group | sg-bastion | `sg-bastion-{region_short}-{env}-{cell}` | sg-bastion-euw2-dev-cell1000 |
| Private Security Group | sg-private | `sg-private-{region_short}-{env}-{cell}` | sg-private-euw2-dev-cell1000 |
| Public NACL | nacl-public | `nacl-public-{region_short}-{env}-{cell}` | nacl-public-euw2-prod-cell0000 |
| Private NACL | nacl-private | `nacl-private-{region_short}-{env}-{cell}` | nacl-private-euw2-prod-cell0000 |

### Singleton/Shared Resources (no cell_name)

Resources that are shared across cells or are region-wide singletons do NOT include `cell_name`:

| Resource | Shortname | Name Pattern | Example |
|----------|-----------|-------------|---------|
| Transit Gateway | tgw | `tgw-{region_short}` | tgw-euw2 |
| TGW Route Table | rt-tgw | `rt-tgw-{region_short}-{table}` | rt-tgw-euw2-dev, rt-tgw-euw1-wan |
| TGW VPC Attachment | tgw-att | `tgw-att-{region_short}-{env}-{vpc_name}` | tgw-att-euw2-dev-main |
| TGW Peering Attachment | tgw-att | `tgw-att-{requester}-{accepter}-pcx` | tgw-att-euw2-euw1-pcx |
| Key Pair | kp | `kp-{region_short}-{env}` | kp-euw2-dev |

### Rationale

- Including `cell_name` in per-cell resources makes it possible to distinguish resources from different cells when viewing them in the same region in the AWS Console.
- Singleton resources (TGW, key pairs) exist once per region or per region/environment, so `cell_name` would be redundant.
- The pattern is consistent and sortable — resources group naturally by type, region, and environment in alphabetical listings.



## State Files

- Each VPC cell has its own state file: `env-{environment}/{region_short}/{cell_name}/terraform.tfstate`
- TGW core has a separate state file: `env-networking/{region_short}-tgw/terraform.tfstate`
- TGW VPC attachments have a separate state file: `env-networking/{region_short}-tgw-vpc-atts/terraform.tfstate`
- Key pairs have a separate state file per environment/region: `env-{environment}/{region_short}/keypair/terraform.tfstate`
- Cross-state references use `terraform_remote_state` data sources