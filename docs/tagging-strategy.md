# Tagging Strategy Documentation

This document defines the comprehensive tagging strategy used across the aws-global-network repository for consistent resource management and compliance.

## Table of Contents

- [Overview](#overview)
- [Tag Standards](#tag-standards)
- [Tag Structure](#tag-structure)
- [Implementation Patterns](#implementation-patterns)
- [Module Guidelines](#module-guidelines)
- [Environment Configuration](#environment-configuration)
- [Examples](#examples)
- [Best Practices](#best-practices)
- [Validation](#validation)

## Overview

Our tagging strategy ensures:

- **Consistency**: Same tag structure across all environments
- **Maintainability**: Centralized tag management
- **Flexibility**: Dynamic references for easy environment setup
- **Compliance**: Required tags for governance and cost allocation

## Tag Standards

### Standard Tag Keys

All tags use **lowercase** keys with underscores for multi-word keys:

| Tag Key | Description | Example Value | Required |
|----------|-------------|---------------|----------|
| `owning_team` | Team responsible for resource | `"NETENG"` | ✅ Yes |
| `managed_by_terraform` | Indicates Terraform management | `true` | ✅ Yes |
| `environment` | Environment name | `"dev"`, `"prod"`, `"test"` | ✅ Yes |
| `region` | AWS region | `"eu-west-2"` | ✅ Yes |
| `region_short` | Short region code | `"euw2"` | ✅ Yes |
| `name` | Resource-specific name | `"bastion-euw2-dev-pub-0-cell1000"` | ✅ Yes |
| `type` | Resource type classification | `"bastion"`, `"application"` | ✅ Yes |

### Name Tag Exception

**The `Name` tag is a special exception** to the lowercase key rule and is **encouraged** for AWS console GUI visibility.

- **Purpose**: Provides human-readable resource names in AWS Management Console
- **Key Format**: Use PascalCase `Name` (not lowercase `name`)
- **Usage**: Should be used alongside our standard lowercase tags
- **Example**: `Name = "bastion-euw2-dev-pub-0-cell1000"`

**Why this exception exists:**

- AWS Management Console prominently displays the `Name` tag
- Improves resource identification and navigation
- Follows AWS documentation recommendations
- Maintains consistency with AWS console expectations

**Implementation pattern:**

```hcl
tags = merge(
  var.default_tags,
  {
    Name = format("bastion-%s-%s-%s-%s", var.region_short, var.environment, each.key, var.cell_name)  # PascalCase for GUI
    type = "bastion"  # lowercase for our standard
  }
)
```

### Tag Value Conventions

- **Strings**: All tag values are strings
- **Booleans**: Use `true`/`false` for boolean values
- **Environment names**: Use lowercase with hyphens for multi-word environments
- **Region codes**: Use AWS standard short codes (euw2, use1, etc.)

## Tag Structure

### Core Tags (Required)

```hcl
{
  owning_team          = "NETENG"
  managed_by_terraform = true
  environment         = "dev"
  region            = "eu-west-2"
  region_short      = "euw2"
}
```

### Resource-Specific Tags

```hcl
{
  name = "bastion-euw2-dev-pub-0"  # Resource naming
  type = "bastion"                  # Resource classification
}
```

## Implementation Patterns

### Environment-Level Configuration

All environments define tags in `locals.tf` using dynamic references:

```hcl
locals {
  region        = "eu-west-2"
  region_short  = "euw2"
  environment   = "dev"
  project_root  = pathexpand("~/repos/aws-global-network")

  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment         = local.environment  # Dynamic reference
    region            = local.region      # Dynamic reference
    region_short      = local.region_short  # Dynamic reference
  }
}
```

### Module-Level Variables

All modules expect tags from caller with empty defaults:

```hcl
variable "default_tags" {
  type = map(string)
  description = "Default tags to apply to all resources"
  # No default value - expects from caller
}
```

### Resource Tagging Pattern

Resources merge default tags with resource-specific tags:

```hcl
resource "aws_instance" "example" {
  # ... resource configuration ...
  
  tags = merge(
    var.default_tags,
    {
      Name = format("bastion-%s-%s-%s-%s", var.region_short, var.environment, each.key, var.cell_name)
      type = "bastion"
    }
  )
}
```

## Module Guidelines

### Module Development Rules

1. **Empty Default Maps**: All modules use empty `default_tags` maps
2. **No Hardcoded Values**: Never hardcode tag values in modules
3. **Expect Tags from Caller**: Modules receive all tags from environment
4. **Merge Pattern**: Always merge default tags with resource-specific tags

### Standard Module Variable Definition

```hcl
variable "default_tags" {
  type = map(string)
  description = "Default tags to apply to all resources"
}
```

### Standard Resource Tagging

```hcl
tags = merge(
  var.default_tags,
  {
    Name = format("resource-%s-%s-%s-%s", var.region_short, var.environment, each.key, var.cell_name)
    type = "resource-type"
  }
)
```

## Environment Configuration

### Directory Structure

```
envs/
├── dev/
│   └── euw2/
│       ├── locals.tf          # Environment-specific tags
│       ├── vpc.tf           # Module calls with default_tags
│       └── ec2s.tf         # Module calls with default_tags
└── test/
    ├── ec2-test/
    └── keypair-test/
```

### Standard locals.tf Pattern

```hcl
locals {
  # Core environment variables
  region        = "eu-west-2"
  region_short  = "euw2"
  environment   = "dev"
  project_root  = pathexpand("~/repos/aws-global-network")

  # Centralized tag configuration
  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment         = local.environment
    region            = local.region
    region_short      = local.region_short
  }
}
```

## Examples

### Complete Environment Example

#### envs/dev/euw2/locals.tf

```hcl
locals {
  region        = "eu-west-2"
  region_short  = "euw2"
  environment   = "dev"
  project_root  = pathexpand("~/repos/aws-global-network")

  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment         = local.environment
    region            = local.region
    region_short      = local.region_short
  }
}
```

#### Module Call Example

```hcl
module "vpc" {
  source           = "../../../modules/create-vpc"
  region       = local.region
  region_short = local.region_short
  environment      = local.environment
  vpc_name         = "main"
  vpc_cidr         = "10.0.0.0/16"
  default_tags     = local.default_tags  # Pass tags to module
}
```

#### Resource Tagging Example

```hcl
resource "aws_subnet" "public" {
  for_each = var.public_subnets
  
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(
    var.default_tags,
    {
      Name  = format("sub-%s-%s-${each.key}-%s", var.region_short, var.environment, var.cell_name)
      scope = "public"
    }
  )
}
```

## Best Practices

### DO ✅

- **Use lowercase keys**: All tag keys should be lowercase
- **EXCEPTION**: Use `Name` (PascalCase) for AWS console GUI visibility
- **Use dynamic references**: Reference `local.environment`, `local.region`, etc.
- **Merge tags properly**: Always merge default tags with resource-specific tags
- **Follow naming conventions**: Use consistent resource naming patterns
- **Keep modules flexible**: Modules should work with any tag configuration

### DON'T ❌

- **Hardcode tag values**: Never hardcode values in modules
- **Use PascalCase keys**: Avoid `Environment`, `ManagedBy` (except `Name` for GUI)
- **Mix tag patterns**: Don't use different patterns across environments
- **Skip required tags**: Always include all required tags
- **Duplicate logic**: Don't repeat tag definitions in multiple places

### Naming Conventions

#### Resource Names (Cell-Scoped)

Resources that belong to a specific VPC/cell include `{cell_name}` as the last segment:

- **VPC**: `vpc-{region_short}-{environment}-{cell_name}`
- **Subnets**: `sub-{region_short}-{environment}-{subnet_key}-{cell_name}`
- **Route Tables**: `rtb-{region_short}-{environment}-{subnet_key}-{cell_name}`
- **Bastion EC2**: `bastion-{region_short}-{environment}-{subnet_key}-{cell_name}`
- **Private EC2**: `private-{region_short}-{environment}-{subnet_key}-{cell_name}`
- **Internet Gateway**: `igw-{region_short}-{environment}-{cell_name}`
- **Egress-only IPv6 IGW**: `egipv6-igw-{region_short}-{environment}-{cell_name}`
- **NAT Gateway**: `ngw-{region_short}-{environment}-{cell_name}`
- **Bastion Security Group**: `sg-bastion-{region_short}-{environment}-{cell_name}`
- **Private Security Group**: `sg-private-{region_short}-{environment}-{cell_name}`
- **Public NACL**: `nacl-public-{region_short}-{environment}-{cell_name}`
- **Private NACL**: `nacl-private-{region_short}-{environment}-{cell_name}`

#### Resource Names (Singleton/Shared — no cell_name)

Resources that are shared across cells or are region-wide singletons:

- **Transit Gateway**: `tgw-{region_short}`
- **TGW Route Table**: `rt-tgw-{region_short}-{environment}`
- **TGW Attachment**: `tgw-att-{region_short}-{environment}-{vpc_name}`
- **Key Pair**: `kp-{region_short}-{environment}`

#### Tag Values

- **Environment**: Lowercase, hyphen-separated if needed (`"dev"`, `"prod"`, `"ec2-test"`)
- **Region**: Full AWS region name (`"eu-west-2"`)
- **Region Short**: AWS short code (`"euw2"`, `"use1"`)
- **Team**: Uppercase team code (`"NETENG"`)

## Validation

### Required Tags Validation

All resources must include these tags:

- ✅ `owning_team`
- ✅ `managed_by_terraform`
- ✅ `environment`
- ✅ `region`
- ✅ `region_short`

### Consistency Checks

- ✅ All tag keys are lowercase
- ✅ All environments use same tag structure
- ✅ All modules expect tags from caller
- ✅ No hardcoded values in modules

### Terraform Validation

```bash
# Validate all environments
terraform validate

# Check plan for tag application
terraform plan | grep -E "(tags|Tags)"
```

## File Structure

### Module Files

```
modules/
├── create-vpc/
│   ├── variables.tf     # Empty default_tags
│   ├── vpc.tf         # Resource tagging with merge()
│   └── subnets.tf     # Resource tagging with merge()
├── create-ec2/
│   ├── variables.tf     # Empty default_tags
│   ├── bastion.tf      # Resource tagging with merge()
│   └── private.tf      # Resource tagging with merge()
└── create-key-pair/
    └── variables.tf     # Empty default_tags
```

### Environment Files

```
envs/
├── dev/euw2/
│   ├── locals.tf       # Dynamic default_tags definition
│   ├── vpc.tf         # Module calls with default_tags
│   └── ec2s.tf       # Module calls with default_tags
└── test/
    ├── ec2-test/
    │   └── locals.tf   # Dynamic default_tags definition
    └── keypair-test/
        └── locals.tf   # Dynamic default_tags definition
```

## Compliance

### AWS Best Practices

- ✅ **Lowercase keys**: Follows AWS recommendations
- ✅ **No restricted prefixes**: Avoids `aws:` prefix
- ✅ **Valid characters**: Uses alphanumeric and underscores only
- ✅ **Length limits**: Stays within AWS tag limits

### Governance Requirements

- ✅ **Cost allocation**: Tags enable proper cost tracking
- ✅ **Resource ownership**: Clear team ownership
- ✅ **Environment tracking**: Proper environment classification
- ✅ **Automation support**: Tags support automated management

## Maintenance

### Adding New Environments

1. Create new environment directory
2. Copy `locals.tf` pattern
3. Update environment-specific values
4. Follow module call pattern with `default_tags`

### Modifying Tags

1. Update `vars/common-tags.tf` for standard tags
2. Update environment `locals.tf` for environment-specific tags
3. Test with `terraform validate` and `terraform plan`

### Adding New Modules

1. Use empty `default_tags` variable
2. Merge `var.default_tags` with resource-specific tags
3. Follow resource naming conventions

---

**This tagging strategy ensures consistent, maintainable, and compliant resource management across the entire aws-global-network repository.**
