# Transit Gateway Core Module

## Overview

The Transit Gateway (TGW) core module (`modules/create-tgw/`) creates and manages the foundational AWS Transit Gateway infrastructure, including the Transit Gateway itself and its associated route tables. This module is designed to enable inter-VPC connectivity while maintaining strict environment isolation through separate routing tables.

## Purpose

The TGW module serves as the central hub for network connectivity within a region, providing:

- **Inter-VPC Communication**: Enables VPCs to communicate with each other without complex peering relationships
- **Environment Isolation**: Separates production, development, and shared services traffic through dedicated route tables
- **Scalability**: Supports up to 5,000 attachments per Transit Gateway
- **Future Multi-Region Connectivity**: Foundation for inter-region TGW peering

## Architecture

```
Transit Gateway (tgw-euw2)
├── Route Table: rt-tgw-euw2-prod    (Production environment)
├── Route Table: rt-tgw-euw2-dev     (Development environment)
└── Route Table: rt-tgw-euw2-shared  (Shared services)
```

## Resources Created

### 1. Transit Gateway

The core Transit Gateway resource with the following configuration:

- **Naming**: `tgw-{region_short}` (e.g., `tgw-euw2`)
- **ASN**: BGP Autonomous System Number for routing (e.g., 64514 for eu-west-2)
- **DNS Support**: Enabled for hostname resolution across VPCs
- **Default Associations**: Disabled (explicit control via route tables)
- **Default Propagations**: Disabled (explicit control via route tables)
- **Multicast Support**: Disabled (can be enabled if needed)
- **VPN ECMP Support**: Disabled by default

### 2. Route Tables

Three route tables are created for environment segmentation:

#### Production Route Table (`rt-tgw-{region_short}-prod`)
- Handles all production VPC traffic
- Isolated from dev and shared environments
- Tagged with `routing_policy = "prod"`

#### Development Route Table (`rt-tgw-{region_short}-dev`)
- Handles all development VPC traffic
- Isolated from prod (can communicate with shared if needed)
- Tagged with `routing_policy = "dev"`

#### Shared Services Route Table (`rt-tgw-{region_short}-shared`)
- Handles shared services VPC traffic
- Can be configured to communicate with prod and/or dev
- Tagged with `routing_policy = "shared"`

## Module Structure

```
modules/create-tgw/
├── providers.tf      # Terraform and provider version constraints
├── variables.tf      # Input variables
├── locals.tf         # Local value computations
├── tgw.tf           # Transit Gateway resource
├── route-tables.tf  # Route table resources
└── outputs.tf       # Module outputs
```

## Input Variables

### Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `default_tags` | map(string) | Standard project tags for resource tagging |
| `region` | string | Full AWS region name (e.g., "eu-west-2") |
| `region_short` | string | Short region code (e.g., "euw2") |
| `amazon_side_asn` | number | BGP ASN for the Transit Gateway |

### Optional Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `dns_support` | string | "enable" | Enable DNS support |
| `vpn_ecmp_support` | string | "disable" | Enable VPN ECMP support |
| `default_route_table_association` | string | "disable" | Enable default route table association |
| `default_route_table_propagation` | string | "disable" | Enable default route table propagation |
| `multicast_support` | string | "disable" | Enable multicast support |

## Outputs

The module exports the following outputs for use by other modules and configurations:

| Output | Description |
|--------|-------------|
| `transit_gateway` | Full Transit Gateway resource object |
| `route_table_prod` | Production route table resource object |
| `route_table_dev` | Development route table resource object |
| `route_table_shared` | Shared services route table resource object |

## Usage Example

```hcl
module "tgw" {
  source = "../../../modules/create-tgw"

  region       = "eu-west-2"
  region_short = "euw2"
  amazon_side_asn  = 64514

  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment          = "networking-tgw"
    region               = "eu-west-2"
    region_short         = "euw2"
  }
}
```

## ASN Assignment

Transit Gateways require a unique BGP ASN for routing. The following ASNs are assigned:

| Region | ASN | Status |
|--------|-----|--------|
| eu-west-2 (London) | 64514 | Deployed |
| us-east-1 (N. Virginia) | 64515 | Reserved |
| ap-southeast-1 (Singapore) | 64516 | Reserved |

ASNs are selected from the private ASN range (64512-65534) to avoid conflicts with public BGP routing.

## Tagging Strategy

All resources created by this module are tagged with:

- **Standard Tags**: From `default_tags` variable
- **Name**: Resource-specific name following naming conventions
- **type**: Resource type identifier
  - Transit Gateway: `type = "transit-gateway"`
  - Route Tables: `type = "transit-gateway-route-table"`
- **routing_policy**: Route table environment identifier (prod/dev/shared)
- **environment**: Environment identifier for cost tracking

## State Management

The Transit Gateway module maintains its own Terraform state file, separate from VPC attachments:

```
State Location: s3://dmac-bootstrap-tfstate/env-networking/euw2-tgw/terraform.tfstate
```

This separation provides:
- **Reduced Blast Radius**: TGW changes don't risk VPC attachment state
- **Independent Deployment**: Deploy core networking separately from attachments
- **Easier Multi-Region**: Each region maintains independent TGW state

## Environment Isolation

The three route tables provide strict environment isolation:

```
┌─────────────────────┐
│  Dev VPC (10.0.0.0) │
└──────────┬──────────┘
           │ attachment
           ▼
    ┌──────────────┐
    │rt-tgw-euw2-dev│ ◄──────┐
    └──────────────┘         │
                             │
┌─────────────────────┐      │      ┌──────────────────┐
│ Prod VPC (10.1.0.0) │      │      │  TGW (tgw-euw2)  │
└──────────┬──────────┘      │      └──────────────────┘
           │ attachment      │
           ▼                 │
    ┌──────────────┐         │
    │rt-tgw-euw2-prod│ ◄─────┤
    └──────────────┘         │
                             │
┌─────────────────────┐      │
│Shared VPC (10.2.0.0)│      │
└──────────┬──────────┘      │
           │ attachment      │
           ▼                 │
    ┌──────────────┐         │
    │rt-tgw-euw2-shared│ ◄───┘
    └──────────────┘
```

VPCs attached to different route tables **cannot** communicate with each other by default.

## Cost Considerations

### Pricing Components

- **Transit Gateway**: ~$36/month (~$0.05/hour)
- **Data Processing**: $0.02/GB for data processed through TGW
- **Attachments**: Billed separately (see TGW VPC Attachment module)

### Cost Optimization

- Deploy one TGW per region (supports multiple VPCs)
- Use route table associations to control traffic flow
- Monitor data transfer costs via CloudWatch

## Validation

After deployment, verify the Transit Gateway configuration:

```bash
# Check TGW status
aws ec2 describe-transit-gateways \
  --transit-gateway-ids tgw-0530e685d439e1f8d

# List route tables
aws ec2 describe-transit-gateway-route-tables \
  --filters "Name=transit-gateway-id,Values=tgw-0530e685d439e1f8d"

# Verify route table is empty (no routes yet)
aws ec2 search-transit-gateway-routes \
  --transit-gateway-route-table-id tgw-rtb-02085d749182ff497 \
  --filters "Name=state,Values=active"
```

## Troubleshooting

### TGW Creation Fails

**Issue**: TGW creation times out or fails
**Resolution**:
- Check AWS service quotas for Transit Gateways (default: 5 per account)
- Verify IAM permissions for `ec2:CreateTransitGateway`

### Route Table Not Created

**Issue**: Route tables fail to create after TGW
**Resolution**:
- Route tables depend on TGW ID - ensure TGW creation completed
- Check for duplicate route table names in the region

### ASN Conflicts

**Issue**: ASN already in use error
**Resolution**:
- Choose a different ASN from the private range (64512-65534)
- Document ASN assignments to avoid conflicts

## Next Steps

After deploying the Transit Gateway module:

1. **Deploy VPC Attachments**: Use `create-tgw-vpc-attachment` module to connect VPCs
2. **Configure VPC Routes**: Add routes in VPC route tables pointing to TGW
3. **Test Connectivity**: Verify inter-VPC communication works as expected
4. **Monitor**: Set up CloudWatch alarms for TGW metrics

## Related Documentation

- [TGW VPC Attachment Module](../tgw-vpc-peering-attachments.md)
- [Transit Gateway Design Decisions](../design/tgws.md)
- [AWS Transit Gateway Documentation](https://docs.aws.amazon.com/vpc/latest/tgw/)
