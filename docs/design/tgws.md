# Transit Gateway Design Decisions

## Overview

This document captures the design decisions, rationale, and trade-offs made during the implementation of the Transit Gateway (TGW) infrastructure for the AWS global network project.

## Table of Contents

- [Architecture Decisions](#architecture-decisions)
- [Naming Conventions](#naming-conventions)
- [State Management](#state-management)
- [Module Design](#module-design)
- [Route Table Strategy](#route-table-strategy)
- [Subnet Selection](#subnet-selection)
- [Security & Isolation](#security--isolation)
- [Scalability Considerations](#scalability-considerations)
- [Cost Optimization](#cost-optimization)
- [Future Enhancements](#future-enhancements)

---

## Architecture Decisions

### Two-Module Approach

**Decision**: Split TGW infrastructure into two separate Terraform modules:
1. **create-tgw**: Transit Gateway + Route Tables
2. **create-tgw-vpc-attachment**: VPC Attachments + Associations + Propagations

**Rationale**:
- **Lifecycle Independence**: TGW is long-lived infrastructure; attachments change frequently
- **State Isolation**: Reduces blast radius - VPC attachment issues don't risk TGW state
- **Deployment Flexibility**: Deploy core TGW once, manage attachments independently
- **Multi-Team Management**: Network team manages TGW, app teams can manage their attachments
- **Clearer Ownership**: Separate modules map to different operational responsibilities

**Alternatives Considered**:
- **Single Module**: Rejected - creates tight coupling between TGW and attachments
- **Three Modules** (TGW, Route Tables, Attachments): Rejected - over-engineered for current needs

**Trade-offs**:
- ✅ Pro: Better separation of concerns
- ✅ Pro: Easier to manage at scale
- ❌ Con: More complex initial setup (multiple state files)
- ❌ Con: Requires data sources to bridge states

---

### State File Separation

**Decision**: Maintain three separate Terraform state files:
1. `env-networking/euw2-tgw/terraform.tfstate` - TGW core
2. `env-networking/euw2-tgw-vpc-atts/terraform.tfstate` - VPC attachments
3. `env-{environment}/euw2/terraform.tfstate` - Individual VPCs

**Rationale**:
- **Risk Mitigation**: Limits the impact of state corruption or accidental changes
- **Parallel Operations**: Multiple teams can work simultaneously without conflicts
- **Faster Operations**: Smaller state files mean faster plan/apply cycles
- **Regional Isolation**: Each region's TGW has independent state

**Implementation**:
- Uses `terraform_remote_state` data source to reference outputs between states
- S3 backend with state locking via DynamoDB (built into lockfile)
- Consistent bucket structure across all networking components

**Trade-offs**:
- ✅ Pro: Enhanced safety and operational independence
- ✅ Pro: Better scalability for large infrastructures
- ❌ Con: More complex to understand for newcomers
- ❌ Con: Requires careful planning of module outputs

---

## Naming Conventions

### Transit Gateway

**Pattern**: `tgw-{region_short}`
**Example**: `tgw-euw2`

**Rationale**:
- **Concise**: Short identifier, easy to reference
- **Region-Scoped**: Clearly indicates which region TGW serves
- **Scalable**: Works well when adding more regions (tgw-use1, tgw-apse1)

**Alternatives Considered**:
- `tgw-{region_full}` (e.g., `tgw-eu-west-2`): Rejected - too verbose
- `tgw-{account}-{region}`: Rejected - unnecessary complexity for single-account setup

### Route Tables

**Pattern**: `rt-tgw-{region_short}-{environment}`
**Example**: `rt-tgw-euw2-dev`

**Rationale**:
- **Hierarchical**: Shows relationship (route table → TGW → region → environment)
- **Sortable**: Natural alphabetical sorting groups related resources
- **Descriptive**: Immediately clear what the route table is for

**Environments**:
- `prod`: Production workloads
- `dev`: Development/testing workloads
- `shared`: Shared services (monitoring, DNS, etc.)

### VPC Attachments

**Pattern**: `tgw-att-{region_short}-{environment}-{vpc_name}`
**Example**: `tgw-att-euw2-dev-main`

**Rationale**:
- **Unique**: Combination ensures no naming conflicts
- **Traceable**: Can identify which VPC and environment from the name alone
- **Consistent**: Follows same region_short pattern as other resources

**VPC Name Component**:
- `main`: Primary VPC in an environment
- `app`: Application-specific VPC
- `db`: Database VPC
- Custom: Any meaningful identifier

---

## State Management

### Backend Configuration

**Decision**: Use S3 backend with built-in state locking

**Configuration**:
```hcl
terraform {
  backend "s3" {
    region       = "eu-west-2"
    bucket       = "dmac-bootstrap-tfstate"
    key          = "env-networking/euw2-tgw/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
```

**Rationale**:
- **Centralized**: All state files in one S3 bucket for easy management
- **Encrypted**: State contains sensitive information (IDs, CIDRs)
- **Locked**: `use_lockfile = true` prevents concurrent modifications
- **Versioned**: S3 versioning enabled for state recovery

**Key Naming Convention**:
- `env-networking/`: Indicates networking-layer infrastructure
- `{region}-tgw`: Specific component and region
- `terraform.tfstate`: Standard Terraform state file name

---

## Module Design

### Input Variables Strategy

**Decision**: Require all critical inputs, provide sensible defaults for optional settings

**Critical Required Variables**:
- **TGW Module**: `region`, `region_short`, `amazon_side_asn`, `default_tags`
- **Attachment Module**: `transit_gateway_id`, `vpc_id`, `subnet_ids`, `transit_gateway_route_table_id`

**Rationale**:
- **Explicit Configuration**: Forces users to think about critical settings
- **No Magic Values**: All important values must be explicitly provided
- **Safe Defaults**: Optional variables have AWS-recommended defaults

**Optional Variables with Defaults**:
- `dns_support = "enable"`: DNS is almost always needed
- `default_route_table_association = "disable"`: We manage associations explicitly
- `appliance_mode_support = "disable"`: Rarely needed, opt-in when required

**Alternatives Considered**:
- **Everything Optional**: Rejected - too easy to misconfigure
- **Minimal Variables**: Rejected - reduces flexibility for advanced use cases

### Output Strategy

**Decision**: Export full resource objects plus convenience accessors

**Pattern**:
```hcl
output "transit_gateway" {
  value = aws_ec2_transit_gateway.this
}

output "transit_gateway_id" {
  value = aws_ec2_transit_gateway.this.id
}
```

**Rationale**:
- **Full Object**: Allows consumers to access any attribute without module updates
- **Convenience Outputs**: Common attributes (ID) are easily accessible
- **Future-Proof**: New AWS attributes are automatically available via full object

**Trade-offs**:
- ✅ Pro: Maximum flexibility for consumers
- ✅ Pro: Reduces need for module updates
- ❌ Con: Larger output structures in remote state

---

## Route Table Strategy

### Three Route Tables (Prod, Dev, Shared)

**Decision**: Create all three route tables in Phase 1, even if not immediately used

**Rationale**:
- **Environment Isolation**: Core security requirement - prod must be isolated from dev
- **Future-Ready**: Shared services route table available when needed
- **Consistent Structure**: Every region follows same three-table pattern
- **No Later Migration**: Avoids having to add route tables later with existing attachments

**Isolation Model**:
```
Dev Route Table:
  - Contains only dev VPC attachments
  - No routes to prod or shared (initially)

Prod Route Table:
  - Contains only prod VPC attachments
  - Strictly isolated from dev
  - May connect to shared services (future)

Shared Route Table:
  - Contains shared service VPCs
  - Can be configured to connect to prod, dev, or both
  - Enables services like centralized DNS, monitoring
```

**Alternatives Considered**:
- **Two Tables (Prod/Non-Prod)**: Rejected - doesn't provide clear shared services path
- **Dynamic Tables**: Rejected - adds complexity without clear benefit
- **One Table**: Rejected - violates security requirement for environment isolation

### Disabled Default Association/Propagation

**Decision**: Set `default_route_table_association = "disable"` and `default_route_table_propagation = "disable"`

**Rationale**:
- **Explicit Control**: Every attachment must explicitly choose its route table
- **Prevent Mistakes**: No accidental cross-environment routing
- **Audit Trail**: All associations are visible in Terraform code
- **Security**: Can't accidentally connect prod to dev by forgetting to specify route table

**Impact**:
- Every attachment **must** include:
  - `aws_ec2_transit_gateway_route_table_association`
  - `aws_ec2_transit_gateway_route_table_propagation`

**Trade-offs**:
- ✅ Pro: Maximum security and control
- ✅ Pro: Clear audit trail
- ❌ Con: Slightly more complex attachment module

---

## Subnet Selection

### Private Subnets Only

**Decision**: Always use private subnets for TGW attachments

**Rationale**:
- **Security**: TGW is internal infrastructure, doesn't need internet access
- **IP Conservation**: Saves public subnet space for actual public-facing resources
- **Best Practice**: Aligns with AWS recommendations

**Enforcement**: Documentation strongly recommends private subnets; no technical enforcement

### One Subnet Per Availability Zone

**Decision**: Require one subnet from each AZ where the VPC has subnets

**Rationale**:
- **High Availability**: TGW can route traffic through any AZ
- **Failover**: If one AZ fails, traffic automatically uses others
- **Performance**: Keeps traffic within same AZ when possible (reduces latency)

**For eu-west-2** (3 AZs):
```
Required subnets:
  - One in eu-west-2a
  - One in eu-west-2b
  - One in eu-west-2c
```

**Trade-offs**:
- ✅ Pro: Maximum availability and performance
- ❌ Con: Uses IP addresses in each AZ (one ENI per subnet)

### Subnet Sizing

**Recommendation**: Minimum /28 (16 IPs) per subnet

**Rationale**:
- TGW uses one IP per subnet for its Elastic Network Interface
- AWS reserves 5 IPs per subnet (.0, .1, .2, .3, .255)
- Leaves adequate buffer for future growth

**Typical Allocation**:
- Small VPCs: /28 (16 IPs) per TGW subnet
- Medium VPCs: /27 (32 IPs) per TGW subnet
- Large VPCs: /26 (64 IPs) per TGW subnet

---

## Security & Isolation

### Environment Isolation Model

**Decision**: Use TGW route tables to enforce environment boundaries

**Isolation Rules**:
1. **Dev ⤳ Prod**: No connectivity (prohibited)
2. **Prod ⤳ Dev**: No connectivity (prohibited)
3. **Shared ⤳ Prod**: Allowed (future configuration)
4. **Shared ⤳ Dev**: Allowed (future configuration)
5. **Dev ⤳ Shared**: Allowed (future configuration)
6. **Prod ⤳ Shared**: Allowed (future configuration)

**Implementation**:
- Dev and Prod VPCs attach to different route tables
- Route tables do not have static routes pointing to each other
- Shared services can be selectively connected later

**Why Not Security Groups?**:
- Security groups are defense-in-depth (additional layer)
- Route-level isolation is more fundamental (traffic never reaches instance)
- Easier to audit and validate at network layer

### DNS Support

**Decision**: Enable DNS support on all TGW resources

**Rationale**:
- Enables hostname resolution across VPCs
- Critical for service discovery patterns
- No significant cost or performance impact

**Configuration**:
- TGW: `dns_support = "enable"`
- VPC Attachments: `dns_support = "enable"`

**How It Works**:
- Instances in VPC-A can resolve hostnames of instances in VPC-B
- Requires both VPCs to have DNS enabled
- Uses AWS Route 53 Resolver for cross-VPC resolution

### Tagging for Security

**Required Tags**:
- `owning_team`: Identifies responsible team (e.g., "NETENG")
- `managed_by_terraform`: Indicates infrastructure-as-code management
- `environment`: Cost allocation and access control
- `type`: Resource type for filtering and automation

**Security Use Cases**:
- **Cost Allocation**: Track spending by team and environment
- **Access Control**: IAM policies can filter by tags
- **Compliance**: Audit reports can verify proper tagging
- **Automation**: Scripts can discover resources by tags

---

## Scalability Considerations

### ASN Assignment Strategy

**Decision**: Assign ASNs from private ASN range (64512-65534)

**Allocation**:
| Region | ASN | Status | Notes |
|--------|-----|--------|-------|
| eu-west-2 | 64514 | Deployed | London |
| us-east-1 | 64515 | Reserved | N. Virginia (future) |
| ap-southeast-1 | 64516 | Reserved | Singapore (future) |

**Rationale**:
- **Private Range**: Avoids conflicts with public BGP (0-64511)
- **Sequential**: Easy to remember and document
- **Reserved Block**: Pre-allocate ASNs for planned regions

**Multi-Region Peering**:
- Each TGW has unique ASN
- Enables inter-region TGW peering in future
- BGP automatically exchanges routes between TGWs

### Attachment Limits

**AWS Limits** (per TGW):
- Maximum attachments: 5,000
- Maximum routes per route table: 10,000
- Maximum route tables: 20

**Our Scaling Strategy**:
- **Current**: 1 attachment per VPC
- **Future**: Multiple VPCs per environment
- **Monitoring**: CloudWatch alerts when approaching limits

**Scaling Patterns**:
1. **Horizontal**: Add more VPCs to same TGW (up to 5,000)
2. **Regional**: Deploy TGW in new regions as needed
3. **Multi-Region**: Peer TGWs across regions for global connectivity

---

## Cost Optimization

### Resource Costs

**Monthly Cost Breakdown**:
- Transit Gateway: $36/month ($0.05/hour)
- VPC Attachment: $36/month per attachment
- Data Transfer: $0.02/GB processed through TGW

**Cost Optimization Strategies**:

1. **Minimize Attachments**
   - Share TGW across multiple workloads in same VPC
   - Don't create separate VPC just for minor isolation

2. **Optimize Data Flow**
   - Keep high-volume traffic within same VPC when possible
   - Use VPC endpoints for AWS services (bypasses TGW)
   - Consider Direct Connect for large on-premises transfers

3. **Rightsizing**
   - One TGW per region (not per environment)
   - Use route tables for isolation, not multiple TGWs

4. **Monitoring**
   - CloudWatch metrics for bytes in/out
   - Cost Explorer tags for cost allocation
   - Regular reviews of attachment utilization

**Cost Comparison**:
- **VPC Peering**: $0.01/GB (cheaper data transfer, no hourly charges)
- **When to use TGW**: 4+ VPCs needing full mesh (TGW is simpler than N² peering connections)
- **When to use Peering**: Simple 2-VPC connectivity

### Tags for Cost Allocation

**Strategy**: Consistent tagging for cost tracking

```hcl
default_tags = {
  owning_team          = "NETENG"      # Cost center
  environment          = "networking"   # Allocation bucket
  managed_by_terraform = true           # Automation tracking
  region               = "eu-west-2"    # Regional costs
}
```

**Cost Reports**:
- Group by `owning_team`: See team spending
- Group by `environment`: See dev vs prod costs
- Filter by `region`: Regional cost breakdown

---

## Future Enhancements

### Phase 2: VPC Route Integration

**Goal**: Enable actual inter-VPC traffic

**Requirements**:
- Add routes in VPC private route tables
- Destination: Remote VPC CIDRs or aggregate (10.0.0.0/8)
- Target: Transit Gateway ID

**Implementation**:
```hcl
resource "aws_route" "to_tgw" {
  route_table_id         = vpc_private_route_table_id
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = data.terraform_remote_state.tgw.outputs.transit_gateway.id
}
```

### Phase 3: Production VPC

**Goal**: Deploy production VPC and attach to TGW

**Components**:
- New VPC in `envs/prod/euw2/`
- New VPC attachment to `rt-tgw-euw2-prod`
- Verify strict isolation from dev environment

### Phase 4: Shared Services VPC

**Goal**: Centralized services (DNS, monitoring, logging)

**Architecture**:
- Deploy shared VPC (e.g., 10.255.0.0/16)
- Attach to `rt-tgw-euw2-shared`
- Add static routes allowing prod/dev to reach shared
- Shared services can see both prod and dev

### Phase 5: Prefix Lists

**Goal**: Simplify route management at scale

**Benefits**:
- Manage CIDR lists centrally
- Reference prefix lists instead of individual CIDRs
- Update multiple routes by updating one prefix list

**Example**:
```hcl
resource "aws_ec2_managed_prefix_list" "prod_networks" {
  name = "prod-networks"
  address_family = "IPv4"
  max_entries    = 10

  entry {
    cidr = "10.1.0.0/20"  # prod-vpc-1
    description = "Production VPC 1"
  }
}
```

### Phase 6: Multi-Region TGW Peering

**Goal**: Connect TGWs across regions

**Architecture**:
```
tgw-euw2 (London) ←→ tgw-use1 (N. Virginia)
   ↕                       ↕
VPCs in EU            VPCs in US
```

**Requirements**:
- Deploy TGW in second region
- Create TGW peering attachment
- Configure inter-region routing
- Manage latency and data transfer costs

**Cost Impact**:
- Inter-region data transfer: $0.02/GB
- Additional attachment: $36/month

### Phase 7: AWS Network Manager

**Goal**: Centralized global network visibility

**Features**:
- Single dashboard for all TGWs and attachments
- Route analyzer for troubleshooting
- Network topology visualization
- Performance monitoring

---

## Lessons Learned

### What Worked Well

1. **Two-Module Approach**: Separation of concerns proved valuable
2. **Explicit Outputs**: Full object exports reduced need for module updates
3. **State Separation**: Isolated failures and enabled parallel work
4. **Documentation-First**: Writing design doc clarified decisions early

### Challenges Encountered

1. **Output Dependencies**: Required updating existing VPC module outputs
   - **Solution**: Added explicit outputs (`vpc_id`, `private_subnet_ids`)
   - **Lesson**: Plan output strategy across modules upfront

2. **State Bridging**: Data sources initially failed due to missing outputs
   - **Solution**: terraform_remote_state with explicit output references
   - **Lesson**: Test data source access early in development

3. **Naming Consistency**: Early draft had inconsistent naming patterns
   - **Solution**: Documented naming conventions before implementation
   - **Lesson**: Establish conventions before writing code

### Recommendations for Future Modules

1. **Design First**: Write design doc before implementing
2. **Output Strategy**: Plan what downstream modules will need
3. **State Architecture**: Decide state separation strategy upfront
4. **Naming Conventions**: Document and follow consistently
5. **Cost Awareness**: Estimate and document costs before deployment

---

## References

### AWS Documentation
- [Transit Gateway Overview](https://docs.aws.amazon.com/vpc/latest/tgw/what-is-transit-gateway.html)
- [TGW Route Tables](https://docs.aws.amazon.com/vpc/latest/tgw/how-transit-gateways-work.html)
- [VPC Attachments](https://docs.aws.amazon.com/vpc/latest/tgw/tgw-vpc-attachments.html)
- [TGW Peering](https://docs.aws.amazon.com/vpc/latest/tgw/tgw-peering.html)

### Internal Documentation
- [TGW Core Module](../features/tgw-module.md)
- [TGW VPC Attachment Module](../tgw-vpc-peering-attachments.md)
- [Project PLAN.md](../../PLAN.md)

### Related RFCs
- RFC 6996: Private ASN Range (64512-65534)
- AWS Well-Architected Framework: Networking Pillar

---

## Change Log

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2026-02-12 | 1.0 | Initial design decisions documented | Claude Sonnet 4.5 |
