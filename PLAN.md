# Plan - AWS Global Network

## Overview

Building a multi-region AWS network architecture using Transit Gateway for inter-VPC and inter-region connectivity. The infrastructure follows a hub-and-spoke model with VPCs in multiple regions connected via Transit Gateways.

## Recent Completions ✅

### Dev Environment Cell-Based Restructure (Latest)

- **Cell-Based Architecture** - Restructured dev environment from flat structure to cell-based organization
- **Directory Structure** - Moved from `envs/dev/euw2/` to `envs/dev/euw2/cell1000/`
- **CIDR Correction** - Fixed dev environment to use correct CIDR allocation (10.1.0.0/20 instead of 10.0.0.0/20)
- **Cell Naming** - Added `cell_name` local variable and updated VPC naming to include cell (vpc-euw2-dev-cell1000)
- **State File Separation** - New state file path: `env-dev/euw2/cell1000/terraform.tfstate`
- **Documentation Updates** - Updated build.md, deployment.md, getting-started.md, and PLAN.md
- **CI/CD Updates** - Updated pipeline.yml to reference new cell1000 path
- **CIDR Alignment** - Now follows DESIGN.md IP allocation strategy (prod=10.0.x.x, dev=10.1.x.x)

**Status**: Cell1000 configuration complete. Ready for deployment. Old flat structure remains for blue-green migration.

### Transit Gateway Implementation

- **Transit Gateway Module** - Created reusable module with TGW and route tables (prod, dev, shared)
- **TGW VPC Attachment Module** - Created module for attaching VPCs with explicit route table association
- **Networking Environment** - New `envs/networking/` structure with separate state files for TGW and attachments
- **VPC Output Refactoring** - Added simplified scalar outputs for remote state consumption with comprehensive documentation
- **Dev VPC Attachment** - Connected dev VPC to dev TGW route table in eu-west-2

**Status**: Core TGW infrastructure complete. Ready for additional VPC attachments and route integration.

## TO-DO

- [ ] Add VPC routes to Transit Gateway for inter-VPC traffic
- [ ] Test end-to-end connectivity through TGW
- [ ] Connect staging and prod VPCs to TGW
- [ ] Document CIDR allocation strategy across regions
- [x] Define environment isolation strategy (prod/dev routing) - Implemented via TGW route tables

---

## High Level Architecture

### Global Resources (Cross-Region)

- **Transit Gateway Peering**: Connect regional TGWs

### Regional Resources (Per Region)

Each region contains:

- **Transit Gateway**
  - Route tables (prod, dev, shared-services)
  - VPC attachments
  - Prefix lists for route filtering
- **VPCs** (3 per region: prod, dev, shared-services)
  - Subnets (3 private, 3 public per VPC)
  - Route tables (1 per subnet)
  - Gateways (IGW, NAT, Egress-only IPv6)
- **EC2 Instances**
  - Bastion hosts (public subnets)
  - Application servers (private subnets)
- **Security**
  - Security Groups (public, private, database tiers)
  - NACLs (subnet-level controls)
- **SSH Key Pairs**

---

## Implementation Phases

### VPC Module ✅

**Status**: Complete

#### Completed

- ✅ VPC with IPv4 and IPv6 support
- ✅ Subnets (3 private, 3 public across 3 AZs)
- ✅ Internet Gateway
- ✅ Egress-only Internet Gateway (IPv6)
- ✅ Regional NAT Gateway (AWSCC provider, auto mode)
- ✅ Route tables (1 per subnet)
- ✅ Public subnet route table associations
- ✅ Public subnet routes to IGW (0.0.0.0/0)
- ✅ Private subnet route table associations
- ✅ Private subnet routes to NAT Gateway (0.0.0.0/0)
- ✅ IPv4 Internet Gateway
- ✅ IPv4 route table associations
- ✅ IPv4 route table routes
  - ✅ Public subnet routes to IGW (0.0.0.0/0)
  - ✅ Private subnet routes to NAT Gateway (0.0.0.0/0)
  - ✅ Public subnet routes to IGW (0.0.0.0/0)
  - ✅ Private subnet routes to NAT Gateway (0.0.0.0/0)
- ✅ IPv6 CIDR blocks for subnets (auto-assigned from VPC)
- ✅ IPv6 egress-only internet gateway
- ✅ IPv6 route table associations
- ✅ IPv6 route table routes
  - ✅ IPv6 routes for private subnets to Egress-only IGW (::/0)
  - ✅ IPv6 routes for public subnets to IGW (::/0)

#### Updates for TGW Support ✅

- ✅ Added simplified scalar outputs for remote state consumption
  - ✅ `vpc_id` - Simple string output (vs. object)
  - ✅ `private_subnet_ids` - Simple list output (vs. map of objects)
  - ✅ `public_subnet_ids` - Simple list output (vs. map of objects)
- ✅ Documented dual output strategy (full objects vs. scalars)
- ✅ Both module and environment outputs updated

#### Future Enhancements

- [ ] Routes to TGW for inter-VPC traffic (10.0.0.0/8)
- [ ] IPv6 routing configuration

#### Module Structure

```
modules/create-vpc/
├── providers.tf       # AWS and AWSCC provider configuration
├── variables.tf       # Input variables
├── outputs.tf         # VPC, subnet, route table, NAT Gateway outputs
├── locals.tf          # Local values, tags, AWSCC tag conversion
├── vpc.tf             # VPC and egress-only IGW
├── subnets.tf         # Private and public subnets
├── gateways.tf        # IGW and Regional NAT Gateway
└── routes.tf          # Route tables and routes
```

#### Key Design Decisions

- **Regional NAT Gateway**: Uses AWSCC provider with auto mode for automatic HA across AZs
- **Cost Optimization**: Single Regional NAT Gateway vs 3 zonal NAT Gateways saves ~$64/month
- **Tag Conversion**: Local value converts default_tags map to AWSCC list format for consistency

---

### SSH Key Pair Module ✅

**Status**: Complete

#### Completed

- ✅ Reusable module for regional SSH key pair generation
- ✅ RSA 4096-bit key generation using TLS provider
- ✅ Private keys saved to `ssh-keys/{region_short}-{environment}.pem` with 0400 permissions
- ✅ AWS Key Pair creation with naming convention `kp-{region_short}-{environment}`
- ✅ Cross-platform home directory support using `pathexpand()`
- ✅ Test environment in `envs/test/keypair-test/`
- ✅ `ssh-keys/` added to `.gitignore`

#### Module Structure

```
modules/create-key-pair/
├── providers.tf      # AWS, TLS, and null providers
├── variables.tf      # project_root, region_short, environment
├── key-pair.tf       # TLS key generation and AWS key pair
└── outputs.tf        # key_pair_name, key_pair_arn
```

#### Usage

```hcl
module "key_pair" {
  source           = "../../modules/create-key-pair"
  project_root     = pathexpand("~/repos/aws-global-network")
  region_short = "euw2"
  environment      = "dev"
}
```

---

### EC2 Module ✅

**Status**: Complete

#### Completed

- ✅ AMI data source (Ubuntu 24.04 LTS)
- ✅ Bastion EC2 instances (Public subnets)
  - One per public subnet (using for_each)
  - Uses VPC default security group if custom SG not provided
  - Associate public IP
- ✅ Private EC2 instances (Private subnets)
  - One per private subnet (using for_each)
  - Uses VPC default security group if custom SG not provided
  - SSH key pair (reference from key-pair module)
  - No public IP
- ✅ Security groups are optional (falls back to VPC default)
- ✅ Test environment validates full integration

#### Design Decisions

- **AMI**: Ubuntu 24.04 LTS (Noble Numbat) with gp3 storage
  - Owner: Canonical (099720109477)
  - Pattern: `ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*`
- **Naming**: `{subnet-key}-{region_short}-{environment}-{vpc_name}`
- **Security Groups**: Optional with fallback to VPC default
  - Allows module testing without custom security groups
  - Uses conditional logic: `var.sg_id != null ? [var.sg_id] : [data.aws_security_group.default.id]`

#### Module Structure

```bash
modules/create-ec2/
├── providers.tf
├── variables.tf       # Instance types, key pair name, security group IDs
├── outputs.tf         # Instance IDs, private/public IPs
├── data.tf            # Ubuntu 24.04 AMI data source
├── bastion.tf         # Bastion instances (public subnets)
└── private.tf         # Private instances (private subnets)
```

### Enterprise Tagging Strategy ✅

**Status**: Complete

#### Completed

- ✅ **Standardized tag keys** across all environments (lowercase with underscores)
- ✅ **Dynamic tag references** (local.region, local.environment, local.region_short)  
- ✅ **Module standardization** with empty default_tags maps
- ✅ **Environment-level centralization** in locals.tf files
- ✅ **Name tag exception** for AWS GUI visibility (PascalCase)
- ✅ **vars/common-tags.tf** centralized configuration
- ✅ **Comprehensive documentation** (docs/tagging-strategy.md, 400+ lines)

#### Tag Structure Implemented

```hcl
default_tags = {
  owning_team          = "NETENG"
  managed_by_terraform = true
  environment         = local.environment  # Dynamic
  region            = local.region      # Dynamic
  region_short      = local.region_short  # Dynamic
}
```

#### Module Integration

- ✅ **create-vpc**: Empty default_tags, expects from caller
- ✅ **create-ec2**: Empty default_tags, expects from caller
- ✅ **create-key-pair**: Empty default_tags, expects from caller

#### Environment Implementation

- ✅ **dev/euw2/cell1000**: Full dynamic tagging with local references
- ✅ **test/ec2-test**: Consistent tag structure
- ✅ **test/keypair-test**: Standardized pattern

#### Resource Tagging Pattern

```hcl
tags = merge(
  var.default_tags,
  {
    Name = format("resource-%s-%s-%s", var.region_short, var.environment, each.key)  # GUI visibility
    type = "resource-type"  # Standard lowercase
  }
)
```

#### Documentation Created

- ✅ **docs/tagging-strategy.md**: Complete 400+ line guide
- ✅ **Implementation examples**: Working code samples
- ✅ **Best practices**: DO/DON'T guidelines
- ✅ **Name tag exception**: AWS console optimization
- ✅ **Validation procedures**: Compliance checking

#### Benefits Achieved

- **Consistency**: Same tag structure across all environments
- **Maintainability**: Single source of truth at environment level
- **Flexibility**: Modules work with any tag configuration
- **Compliance**: Required tags always applied
- **AWS Best Practices**: Lowercase keys with Name tag exception

---

### Transit Gateway Module ✅

**Status**: Complete

#### Completed

- ✅ Transit Gateway resource (`aws_ec2_transit_gateway`)
- ✅ Three TGW route tables (prod, dev, shared)
- ✅ Configurable BGP ASN (Amazon side)
- ✅ DNS support enabled by default
- ✅ Disabled default route table association/propagation (explicit control)
- ✅ Full resource object outputs for all components

#### Module Structure

```
modules/create-tgw/
├── providers.tf        # AWS provider configuration
├── variables.tf        # TGW configuration variables
├── outputs.tf          # TGW and route table outputs
├── locals.tf           # TGW naming convention
├── tgw.tf              # Transit Gateway resource
└── route-tables.tf     # Prod, dev, and shared route tables
```

#### Key Design Decisions

- **Naming Convention**: `tgw-{region_short}` (e.g., tgw-euw2)
- **Route Table Naming**: `rt-tgw-{region_short}-{environment}` (e.g., rt-tgw-euw2-prod)
- **Explicit Control**: Default route table association/propagation disabled for fine-grained control
- **BGP ASN**: Configurable per region (e.g., 64512 for eu-west-2)
- **Environment Isolation**: Separate route tables for prod, dev, and shared services

#### Configuration Variables

- `amazon_side_asn` - BGP ASN for Transit Gateway (required)
- `dns_support` - Enable DNS support (default: "enable")
- `vpn_ecmp_support` - Enable ECMP for VPN (default: "disable")
- `default_route_table_association` - Default RT association (default: "disable")
- `default_route_table_propagation` - Default RT propagation (default: "disable")
- `multicast_support` - Enable multicast (default: "disable")

#### Outputs

- `transit_gateway` - Full Transit Gateway resource object
- `route_table_prod` - Production route table resource object
- `route_table_dev` - Development route table resource object
- `route_table_shared` - Shared services route table resource object

---

### Transit Gateway VPC Attachment Module ✅

**Status**: Complete

#### Completed

- ✅ VPC attachment resource (`aws_ec2_transit_gateway_vpc_attachment`)
- ✅ Route table association (`aws_ec2_transit_gateway_route_table_association`)
- ✅ Route table propagation (`aws_ec2_transit_gateway_route_table_propagation`)
- ✅ Explicit route table control (no default associations)
- ✅ DNS support enabled by default
- ✅ Appliance mode support (configurable)

#### Module Structure

```
modules/create-tgw-vpc-attachment/
├── providers.tf           # AWS provider configuration
├── variables.tf           # Attachment configuration variables
├── outputs.tf             # Attachment resource output
├── locals.tf              # Attachment naming convention
└── vpc-attachment.tf      # VPC attachment, association, and propagation
```

#### Key Design Decisions

- **Naming Convention**: `tgw-att-{region_short}-{environment}-{vpc_name}` (e.g., tgw-att-euw2-dev-main)
- **Explicit Association**: Each attachment is explicitly associated with a specific TGW route table
- **Automatic Propagation**: Routes are automatically propagated to the associated route table
- **Subnet Selection**: Uses private subnets for TGW attachments (one per AZ)
- **No Default Tables**: Default route table association and propagation disabled for control

#### Configuration Variables

- `transit_gateway_id` - TGW ID to attach to (required)
- `vpc_id` - VPC ID to attach (required)
- `subnet_ids` - List of subnet IDs for attachment (required)
- `transit_gateway_route_table_id` - TGW route table to associate with (required)
- `environment` - Environment name (dev, prod, shared) (required)
- `vpc_name` - VPC name for attachment naming (required)
- `dns_support` - Enable DNS support (default: "enable")
- `appliance_mode_support` - Enable appliance mode (default: "disable")

#### Outputs

- `vpc_attachment` - Full VPC attachment resource object

---

### Networking Environment Structure ✅

**Status**: Complete

#### Completed

- ✅ Created `envs/networking/` directory for centralized network resources
- ✅ Separate state files for TGW and TGW attachments
- ✅ Region-based organization (euw2)
- ✅ Remote state data sources for cross-environment references

#### Directory Structure

```
envs/networking/
└── euw2/
    ├── tgw/                      # Transit Gateway deployment
    │   ├── backend.tf            # S3 backend: "tgw-euw2"
    │   ├── providers.tf          # AWS provider (eu-west-2)
    │   ├── locals.tf             # Region short, default tags
    │   ├── tgw.tf                # create-tgw module call
    │   └── outputs.tf            # TGW and route table outputs
    │
    └── tgw-vpc-atts/             # TGW VPC Attachments
        ├── backend.tf            # S3 backend: "tgw-vpc-atts-euw2"
        ├── providers.tf          # AWS provider (eu-west-2)
        ├── locals.tf             # Region short, default tags
        ├── data.tf               # Remote state: tgw-euw2, dev-euw2
        ├── vpc-attachments.tf    # Attachment module calls
        └── outputs.tf            # Attachment outputs
```

#### Remote State Configuration

**TGW State (`tgw-euw2`):**

- Consumed by: `tgw-vpc-atts` environment
- Outputs: `transit_gateway.id`, `route_table_dev.id`, `route_table_prod.id`

**Dev VPC State (`dev-euw2`):**

- Consumed by: `tgw-vpc-atts` environment
- Outputs: `vpc_id`, `private_subnet_ids` (simplified scalars for remote state)

#### Implementation Pattern

**TGW Deployment (envs/networking/euw2/tgw/):**

```hcl
module "tgw_euw2" {
  source = "../../../../modules/create-tgw"

  amazon_side_asn      = 64512
  region           = "eu-west-2"
  region_short     = "euw2"
  default_tags         = local.default_tags
}
```

**VPC Attachment (envs/networking/euw2/tgw-vpc-atts/):**

```hcl
module "attachment_dev_vpc" {
  source = "../../../../modules/create-tgw-vpc-attachment"

  transit_gateway_id             = data.terraform_remote_state.tgw.outputs.transit_gateway.id
  vpc_id                         = data.terraform_remote_state.dev_vpc.outputs.vpc_id
  subnet_ids                     = data.terraform_remote_state.dev_vpc.outputs.private_subnet_ids
  transit_gateway_route_table_id = data.terraform_remote_state.tgw.outputs.route_table_dev.id

  environment      = "dev"
  region_short = "euw2"
  vpc_name         = "main"
  default_tags     = local.default_tags
}
```

#### Key Design Decisions

- **State Isolation**: TGW and attachments in separate state files for independent lifecycle
- **Centralized Networking**: All transit gateway resources in `envs/networking/`
- **Cross-State References**: Uses `terraform_remote_state` for VPC and TGW outputs
- **Environment Isolation**: Dev VPCs attach to dev route table, prod to prod route table

---

### VPC Output Refactoring ✅

**Status**: Complete

#### Completed

- ✅ Dual output strategy documented
- ✅ Added simplified scalar outputs to VPC module
- ✅ Added simplified scalar outputs to environment outputs
- ✅ Comprehensive inline documentation explaining both output types

#### Output Types

**Complex Object Outputs (Internal Use):**

- `vpc` - Object with `{id, cidr_block}`
- `private_subnets` - Map of full subnet objects
- `public_subnets` - Map of full subnet objects
- `private_subnets_id` - Map with `{id, cidr_ipv4, cidr_ipv6}` per subnet

**Use Case:**

- Internal module consumption within same Terraform root
- Rich attribute access (e.g., `module.vpc.vpc.cidr_block`)
- No terraform_remote_state needed

**Simplified Scalar Outputs (Remote State Use):**

- `vpc_id` - Simple string
- `private_subnet_ids` - Simple list of IDs
- `public_subnet_ids` - Simple list of IDs

**Use Case:**

- Cross-environment access via `terraform_remote_state`
- Clean consumption by TGW attachments
- No complex for-loops needed in consumers

#### Documentation Added

- Module-level comments in `modules/create-vpc/outputs.tf`
- Environment-level comments in `envs/dev/euw2/cell1000/outputs.tf`
- Explained why both output sets coexist
- Examples showing internal vs. remote state usage

#### Design Rationale

**Why Both Output Sets?**

1. **Different Access Patterns** - Internal (direct) vs. remote state (indirect)
2. **Backward Compatibility** - Existing code depends on complex outputs
3. **Terraform Best Practice** - Common to provide both detailed and simplified outputs
4. **Consumer Convenience** - Right tool for the right job

**Example Comparison:**

Without simplified outputs (complex):

```hcl
vpc_id     = data.terraform_remote_state.vpc.outputs.vpc.id
subnet_ids = [for k, v in data.terraform_remote_state.vpc.outputs.private_subnets_id : v.id]
```

With simplified outputs (clean):

```hcl
vpc_id     = data.terraform_remote_state.vpc.outputs.vpc_id
subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids
```

---

### Security Module ✅

**Status**: Complete

#### Completed

**Security Groups:**

- ✅ Bastion security group (public tier)
  - ✅ SSH (port 22) inbound from anywhere (0.0.0.0/0)
  - ✅ ICMPv4 inbound from anywhere (0.0.0.0/0)
  - ✅ ICMPv6 inbound from anywhere (::/0)
  - ✅ All traffic outbound
- ✅ Private security group (private tier)
  - ✅ All traffic inbound from bastion security group
  - ✅ All traffic outbound

**Network ACLs:**

- ✅ Public subnet NACL
  - ✅ Inbound: SSH (22), HTTP (80), HTTPS (443)
  - ✅ Inbound: ICMPv4 and ICMPv6
  - ✅ Outbound: All IPv4 traffic (0.0.0.0/0)
  - ✅ Outbound: All IPv6 traffic (::/0)
- ✅ Private subnet NACL
  - ✅ Inbound: All traffic from VPC CIDR
  - ✅ Outbound: All IPv4 traffic (0.0.0.0/0)
  - ✅ Outbound: All IPv6 traffic (::/0)

#### Module Structure

```
modules/security/
├── providers.tf
├── variables.tf
├── outputs.tf
├── security-groups.tf # Bastion and private security groups
└── nacls.tf           # Public and private NACLs
```

#### Key Design Decisions

- **Stateless NACLs**: Explicit egress rules required for return traffic
- **Security Group References**: Private SG allows all traffic from bastion SG (not CIDR-based)
- **ICMP Support**: Both IPv4 (icmp) and IPv6 (protocol 58) enabled for connectivity testing
- **Naming Convention**: `sg-{type}-{region_short}-{environment}` and `nacl-{type}-{region_short}-{environment}`

---

### Inter-VPC Routing

**Status**: Planning

#### Requirements

**Agreed Architecture Decisions:**

1. **Private Subnets Only**: Only private subnets will have routes to TGW (no public subnet routing to TGW)
2. **Destination CIDR**: 10.0.0.0/8 traffic from private subnets will route via TGW
3. **All Private Subnets**: ALL private subnet route tables (priv-0, priv-1, priv-2) get TGW routes
4. **No Routing Policies**: At this stage, no complex routing policies - VPCs just need to attach to correct TGW route table (prod → prod table, dev → dev table)
5. **No Blackhole Routes**: TGW blackhole routes are not needed
6. **VPC Module Enhancement**: Add optional TGW routing capability to VPC module (Option A - reusable approach)
7. **TGW ID Input**: Pass Transit Gateway ID as module variable (explicit, flexible, testable)
8. **Existing Infrastructure**: Current deployed dev/euw2/cell1000 VPC needs TGW routes added
9. **Route Propagation**: Verify TGW route tables automatically receive VPC CIDR routes via propagation (already enabled in attachment module)

#### Implementation Scope

**What needs to be done:**

- [ ] Update VPC module to accept optional `transit_gateway_id` variable
- [ ] Add conditional TGW routes in VPC module (private subnets only, 10.0.0.0/8 destination)
- [ ] Update environment configurations to pass TGW ID to VPC module
- [ ] Apply changes to existing dev/euw2/cell1000 deployment
- [ ] Verify TGW route table propagation is working (VPC CIDRs appear in TGW route tables)
- [ ] Test inter-VPC connectivity (dev-to-dev communication)

**What is NOT being done:**

- ❌ Public subnet TGW routing
- ❌ Complex routing policies or traffic filtering
- ❌ TGW blackhole routes
- ❌ Cross-region routing (future phase)
- ❌ Shared services VPC (not yet deployed)

### Multi-Region Expansion

**Status**: Not started

#### Requirements

- [ ] Deploy VPC module in 4 regions (us-east-1, us-west-2, eu-west-2, ap-southeast-1)
- [ ] Create Transit Gateway in each region
- [ ] Configure TGW peering between regions
- [ ] Set up cross-region routing
- [ ] Test inter-region connectivity
- [ ] Document latency and failover behavior

---

## Automation & Tooling

### CI/CD Pipelines

- [ ] Terraform format check (terraform fmt)
- [ ] Terraform validation (terraform validate)
- [ ] TFLint for best practices
- [ ] Infracost for cost estimation
- [ ] Terraform docs generation
- [ ] Security scanning (Checkov, tfsec)

### Development Tools

- [ ] Taskfile for common operations
- [ ] Pre-commit hooks
- [ ] AWS Cloud Control Provider (optional)
- [ ] Terraform Cloud/Enterprise integration

### Monitoring & Observability

- [ ] VPC Flow Logs to CloudWatch
- [ ] Transit Gateway metrics
- [ ] Cost allocation tags
- [ ] CloudWatch dashboards
- [ ] Alerting for connectivity issues

---

## CIDR Allocation Strategy

### Region: eu-west-2 (London)

**Production Environment (10.0.0.0/16):**

- Prod cell0000: 10.0.0.0/20
- Prod cell0001: 10.0.16.0/20
- Prod cell0002: 10.0.32.0/20

**Development Environment (10.1.0.0/16):**

- Dev cell1000: 10.1.0.0/20
- Dev cell1001: 10.1.16.0/20
- Dev cell1002: 10.1.32.0/20

### Region: us-east-1 (N. Virginia)

**Production Environment (10.2.0.0/16):**

- Prod cell0000: 10.2.0.0/20
- Prod cell0001: 10.2.16.0/20
- Prod cell0002: 10.2.32.0/20

**Development Environment (10.3.0.0/16):**

- Dev cell1000: 10.3.0.0/20
- Dev cell1001: 10.3.16.0/20
- Dev cell1002: 10.3.32.0/20

### Region: us-west-2 (Oregon)

**Production Environment (10.4.0.0/16):**

- Prod cell0000: 10.4.0.0/20
- Prod cell0001: 10.4.16.0/20
- Prod cell0002: 10.4.32.0/20

**Development Environment (10.5.0.0/16):**

- Dev cell1000: 10.5.0.0/20
- Dev cell1001: 10.5.16.0/20
- Dev cell1002: 10.5.32.0/20

### Region: ap-southeast-1 (Singapore)

**Production Environment (10.6.0.0/16):**

- Prod cell0000: 10.6.0.0/20
- Prod cell0001: 10.6.16.0/20
- Prod cell0002: 10.6.32.0/20

**Development Environment (10.7.0.0/16):**

- Dev cell1000: 10.7.0.0/20
- Dev cell1001: 10.7.16.0/20
- Dev cell1002: 10.7.32.0/20

---

## Next Steps

1. **VPC Route Integration**: Add routes from VPC route tables to TGW for inter-VPC traffic (10.0.0.0/8)
2. **Connectivity Testing**: Validate end-to-end connectivity through TGW
   - Dev VPC to Dev VPC routing
   - Private instance to private instance (cross-VPC)
   - Test route table isolation (dev vs. prod)
3. **Additional VPC Attachments**: Connect staging and prod VPCs to appropriate TGW route tables
4. **Documentation**: Create architecture diagrams showing complete network topology with TGW
5. **Multi-Region Expansion**:
   - Deploy TGW in additional regions (us-east-1, us-west-2, ap-southeast-1)
   - Configure TGW peering between regions
   - Set up cross-region routing
