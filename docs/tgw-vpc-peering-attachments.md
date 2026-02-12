# Transit Gateway VPC Attachment Module

## Overview

The Transit Gateway VPC Attachment module (`modules/create-tgw-vpc-attachment/`) manages the connections between VPCs and a Transit Gateway. This module handles VPC attachment creation, route table association, and route propagation to enable inter-VPC connectivity.

## Purpose

The VPC Attachment module bridges VPCs to the Transit Gateway, providing:

- **VPC-to-TGW Connectivity**: Creates attachment resources linking VPCs to Transit Gateway
- **Route Table Association**: Associates attachments with specific TGW route tables for environment isolation
- **Automatic Route Propagation**: Enables automatic advertisement of VPC CIDRs to TGW route tables
- **Per-Environment Segmentation**: Controls which VPCs can communicate based on route table associations

## Architecture

```
VPC (10.0.0.0/20)
├── Private Subnet AZ-A (10.0.0.0/24) ──┐
├── Private Subnet AZ-B (10.0.1.0/24) ──┼─► TGW Attachment
└── Private Subnet AZ-C (10.0.2.0/24) ──┘    │
                                             │ Association
                                             ▼
                                    TGW Route Table (dev)
                                             │ Propagation
                                             ▼
                                    Route: 10.0.0.0/20 → attachment
```

## Resources Created

### 1. VPC Attachment

Creates a Transit Gateway VPC attachment with:

- **Naming**: `tgw-att-{region_short}-{environment}-{vpc_name}` (e.g., `tgw-att-euw2-dev-main`)
- **Subnets**: One subnet per Availability Zone (typically 3)
- **DNS Support**: Enabled for cross-VPC hostname resolution
- **Appliance Mode**: Disabled by default (enable for security appliances)
- **Default Associations**: Disabled (explicit control)

### 2. Route Table Association

Associates the VPC attachment with a specific Transit Gateway route table:

- **Purpose**: Determines which route table manages traffic for this VPC
- **Environment Isolation**: Dev attachments → dev route table, Prod → prod route table
- **One-to-One Mapping**: Each attachment associates with exactly one route table

### 3. Route Table Propagation

Enables automatic route propagation from VPC to Transit Gateway:

- **Automatic Routes**: VPC CIDR blocks are automatically advertised to the route table
- **Dynamic Updates**: Routes update automatically if VPC CIDR changes
- **Bidirectional Learning**: TGW learns VPC routes without manual configuration

## Module Structure

```
modules/create-tgw-vpc-attachment/
├── providers.tf       # Terraform and provider version constraints
├── variables.tf       # Input variables
├── locals.tf          # Local value computations
├── vpc-attachment.tf  # VPC attachment, association, and propagation
└── outputs.tf         # Module outputs
```

## Input Variables

### Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `default_tags` | map(string) | Standard project tags |
| `transit_gateway_id` | string | ID of the Transit Gateway to attach to |
| `vpc_id` | string | ID of the VPC to attach |
| `subnet_ids` | list(string) | List of subnet IDs (one per AZ) for the attachment |
| `transit_gateway_route_table_id` | string | TGW route table ID to associate with |
| `environment` | string | Environment identifier (dev/prod/shared) |
| `aws_region_short` | string | Short region code (e.g., "euw2") |
| `vpc_name` | string | VPC identifier for naming (e.g., "main") |

### Optional Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `dns_support` | string | "enable" | Enable DNS support for the attachment |
| `appliance_mode_support` | string | "disable" | Enable appliance mode (for security appliances) |

## Outputs

| Output | Description |
|--------|-------------|
| `vpc_attachment` | Full VPC attachment resource object |
| `attachment_id` | VPC attachment ID (convenience accessor) |

## Usage Example

```hcl
module "attachment_dev_vpc" {
  source = "../../../modules/create-tgw-vpc-attachment"

  # Transit Gateway configuration
  transit_gateway_id             = "tgw-0530e685d439e1f8d"
  transit_gateway_route_table_id = "tgw-rtb-02085d749182ff497"

  # VPC configuration
  vpc_id     = "vpc-0c6d9497b7045cb6f"
  subnet_ids = [
    "subnet-0ee6833649a562666",  # AZ-A
    "subnet-0344ed1f2277aa272",  # AZ-B
    "subnet-051d4c36e661942c8"   # AZ-C
  ]

  # Metadata
  environment      = "dev"
  aws_region_short = "euw2"
  vpc_name         = "main"

  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment          = "networking-tgw-vpc-atts"
    region               = "eu-west-2"
    region_short         = "euw2"
  }
}
```

## Subnet Selection

### Best Practices

**Use Private Subnets**: Always use private subnets for TGW attachments
- Public subnets are unnecessary (TGW is internal)
- Reduces security exposure
- Conserves public subnet space

**One Subnet Per AZ**: Include one subnet from each Availability Zone
- Provides high availability
- Enables cross-AZ failover
- Required for multi-AZ deployments

**Consistent Subnet Sizing**: Use adequately sized subnets
- Minimum /28 (16 IPs) per subnet recommended
- TGW uses one IP per subnet for Elastic Network Interface (ENI)
- Plan for future growth

### Example Subnet Configuration

```hcl
# Dev VPC: 10.0.0.0/20
subnet_ids = [
  "subnet-xxx",  # 10.0.0.0/24 (priv-0, eu-west-2a)
  "subnet-yyy",  # 10.0.1.0/24 (priv-1, eu-west-2b)
  "subnet-zzz"   # 10.0.2.0/24 (priv-2, eu-west-2c)
]
```

## State Management

VPC attachments maintain separate state from the Transit Gateway itself:

```
State Location: s3://dmac-bootstrap-tfstate/env-networking/euw2-tgw-vpc-atts/terraform.tfstate
```

### Why Separate State?

- **Independent Lifecycle**: Add/remove VPC attachments without affecting TGW
- **Reduced Risk**: Attachment failures don't impact core TGW infrastructure
- **Easier Management**: Smaller state files are easier to manage and debug
- **Multi-Team Ownership**: Different teams can manage VPC attachments

## Route Propagation Behavior

When route propagation is enabled, the Transit Gateway automatically learns routes:

### Automatic Route Creation

```
VPC CIDR: 10.0.0.0/20
           ↓ (propagates)
TGW Route Table Entry:
  Destination: 10.0.0.0/20
  Target: tgw-attach-030eabc8625764826
  Type: propagated
  State: active
```

### What Gets Propagated

- **VPC CIDR Block**: Primary VPC CIDR (e.g., 10.0.0.0/20)
- **Secondary CIDRs**: Any additional CIDR blocks associated with the VPC
- **IPv6 CIDRs**: If VPC has IPv6 enabled

### What Does NOT Get Propagated

- **Subnet CIDRs**: Individual subnet routes are not propagated
- **VPC Route Table Entries**: Existing routes in VPC route tables
- **Static Routes**: Must be added manually to TGW route tables

## Environment Isolation Enforcement

The module enforces environment isolation through route table association:

```
Dev VPC ──(attachment)──► Dev Route Table
                          ├── Route: 10.0.0.0/20 (Dev VPC)
                          └── [no routes to prod]

Prod VPC ──(attachment)──► Prod Route Table
                           ├── Route: 10.1.0.0/20 (Prod VPC)
                           └── [no routes to dev]
```

**Result**: Dev and Prod VPCs cannot communicate even though they share the same TGW.

## Data Sources

The attachment module typically reads data from remote state:

```hcl
# Read TGW information
data "terraform_remote_state" "tgw" {
  backend = "s3"
  config = {
    bucket = "dmac-bootstrap-tfstate"
    key    = "env-networking/euw2-tgw/terraform.tfstate"
    region = "eu-west-2"
  }
}

# Read VPC information
data "terraform_remote_state" "dev_vpc" {
  backend = "s3"
  config = {
    bucket = "dmac-bootstrap-tfstate"
    key    = "env-dev/euw2/terraform.tfstate"
    region = "eu-west-2"
  }
}

# Use in module call
module "attachment_dev_vpc" {
  source = "../../../modules/create-tgw-vpc-attachment"

  transit_gateway_id = data.terraform_remote_state.tgw.outputs.transit_gateway.id
  vpc_id             = data.terraform_remote_state.dev_vpc.outputs.vpc_id
  subnet_ids         = data.terraform_remote_state.dev_vpc.outputs.private_subnet_ids
  # ...
}
```

## Attachment Lifecycle

### Creation Process

1. **VPC Attachment**: Creates ENI in each specified subnet (~2 minutes)
2. **Pending State**: Attachment enters "pending" state during ENI creation
3. **Available State**: Attachment becomes "available" when ready
4. **Association**: Links attachment to specified route table
5. **Propagation**: Begins advertising VPC CIDR to route table

### Update Process

- **Subnet Changes**: Requires replacement (cannot modify subnets in-place)
- **Route Table Change**: Can be updated in-place (association update)
- **Tag Updates**: Applied immediately without disruption

### Deletion Process

1. **Disassociation**: Removes route table association
2. **Route Removal**: Propagated routes are automatically removed
3. **Attachment Deletion**: ENIs are deleted from subnets
4. **Cleanup**: All resources fully removed within ~2 minutes

## Cost Considerations

### Pricing Components

- **VPC Attachment**: ~$36/month (~$0.05/hour per attachment)
- **Data Transfer**: $0.02/GB for data processed through the attachment
- **No Subnet Charges**: Subnets themselves don't incur additional costs

### Cost Optimization

- **Minimize Attachments**: Share TGW across multiple workloads in same VPC
- **Monitor Data Transfer**: Use VPC Flow Logs to identify high-traffic patterns
- **Right-Size Infrastructure**: Don't over-provision VPCs just for TGW

## Validation

After deployment, verify the VPC attachment:

```bash
# Check attachment status
aws ec2 describe-transit-gateway-vpc-attachments \
  --transit-gateway-attachment-ids tgw-attach-030eabc8625764826

# Verify route table association
aws ec2 get-transit-gateway-attachment-associations \
  --transit-gateway-attachment-id tgw-attach-030eabc8625764826

# Check propagated routes
aws ec2 search-transit-gateway-routes \
  --transit-gateway-route-table-id tgw-rtb-02085d749182ff497 \
  --filters "Name=type,Values=propagated"
```

Expected output shows:
- Attachment state: `available`
- Association: Points to correct route table
- Propagated route: VPC CIDR visible in route table

## Troubleshooting

### Attachment Stuck in Pending

**Issue**: Attachment remains in "pending" state for >5 minutes
**Resolution**:
- Check subnet security groups allow outbound traffic
- Verify subnets have available IP addresses
- Ensure IAM permissions include `ec2:CreateNetworkInterface`

### Route Not Propagating

**Issue**: VPC CIDR not appearing in TGW route table
**Resolution**:
- Verify propagation resource was created (`aws_ec2_transit_gateway_route_table_propagation`)
- Check attachment state is "available"
- Confirm route table ID is correct

### Cannot Connect Between VPCs

**Issue**: VPCs attached to TGW cannot communicate
**Resolution**:
1. Verify both VPCs have attachments in "available" state
2. Check both attachments are in the **same** route table (or have routes between tables)
3. Ensure VPC route tables have routes pointing to TGW
4. Verify security groups and NACLs allow traffic

### Subnet Cannot Be Attached

**Issue**: Error when trying to attach specific subnets
**Resolution**:
- Ensure subnets are in different Availability Zones
- Verify subnets belong to the specified VPC
- Check subnets are not already used by another TGW attachment

## Security Considerations

### Network Segmentation

- **Route Table Isolation**: Keep prod and dev in separate route tables
- **Least Privilege Routing**: Only propagate routes that are needed
- **Security Group Rules**: Don't rely solely on TGW for security

### Monitoring

Set up CloudWatch alarms for:
- **Attachment State Changes**: Alert when attachments go down
- **Packet Drop Counts**: High drops may indicate misconfigurations
- **Bytes In/Out**: Monitor for unusual traffic patterns

### Compliance

- **Tag All Resources**: Ensure all attachments have proper cost allocation tags
- **Document Routing**: Maintain up-to-date diagrams of VPC connectivity
- **Audit Route Changes**: Enable CloudTrail logging for TGW API calls

## Next Steps

After deploying VPC attachments:

1. **Update VPC Route Tables**: Add routes pointing to TGW for inter-VPC traffic
2. **Test Connectivity**: Verify instances can communicate across VPCs
3. **Configure Shared Services**: Attach shared services VPC if applicable
4. **Set Up Monitoring**: Create CloudWatch dashboards for TGW metrics
5. **Document Topology**: Update network diagrams with new connectivity

## Related Documentation

- [Transit Gateway Core Module](./features/tgw-module.md)
- [Transit Gateway Design Decisions](./design/tgws.md)
- [AWS TGW VPC Attachments](https://docs.aws.amazon.com/vpc/latest/tgw/tgw-vpc-attachments.html)
