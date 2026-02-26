# Spec 06 - Deploy Region eu-west-1 and Test Inter-Region Connectivity

## Overview

Deploy a full eu-west-1 (Ireland) regional stack to mirror what is currently running in eu-west-2 (London). This includes a Transit Gateway for euw1, two dev cells (cell3000 and cell3001) and two prod cells (cell2000 and cell2001), TGW-VPC attachments for both environments, and a TGW Peering Attachment linking the euw1 and euw2 Transit Gateways. After deployment, validate end-to-end cross-region connectivity by pinging from an euw1 private host to an euw2 private host and vice versa.

**Status**: Complete — euw1 TGW (ASN 64515), dev cells (cell3000/cell3001), prod cells (cell2000/cell2001), TGW-VPC attachments (dev + prod environments), and TGW Peering (euw2↔euw1) fully deployed and tested. Inter-region connectivity (euw1 ↔ euw2 ping) verified.

---

## Goals

1. Create `envs/networking/euw1/tgw/` — Transit Gateway for eu-west-1 (ASN 64515).
2. Create `envs/dev/euw1/cell3000/` — dev VPC cell3000 (10.17.0.0/20) in eu-west-1.
3. Create `envs/dev/euw1/cell3001/` — dev VPC cell3001 (10.17.16.0/20) in eu-west-1.
4. Create `envs/prod/euw1/cell2000/` — prod VPC cell2000 (10.16.0.0/20) in eu-west-1.
5. Create `envs/prod/euw1/cell2001/` — prod VPC cell2001 (10.16.16.0/20) in eu-west-1.
6. Create `envs/networking/euw1/tgw-vpc-atts/` — TGW-VPC Attachments for all euw1 cells.
7. Create `envs/networking/global/tgw-peering/` — TGW Peering Attachment between euw2 and euw1.
8. Update `scripts/deploy.sh` — add Phase 4 for TGW Peering Attachment destroy support in `scripts/destroy.sh`.
9. Update `specs/index.md` to mark feature 06 as Complete.
10. Validate all new directories pass `terraform validate` and `tflint`.
11. Deploy to AWS and test inter-region connectivity (ping euw1 → euw2 and euw2 → euw1).

---

## Context

### IP Allocation for euw1

Per `specs/DESIGN.md`, eu-west-1 uses the `10.16.0.0/12` block:

| VPC Name               | Environment | VPC CIDR       | Notes                  |
|------------------------|-------------|----------------|------------------------|
| vpc-euw1-prod-cell2000 | prod        | 10.16.0.0/20   | prod /16 = 10.16.0.0/16 |
| vpc-euw1-prod-cell2001 | prod        | 10.16.16.0/20  |                        |
| vpc-euw1-dev-cell3000  | dev         | 10.17.0.0/20   | dev /16 = 10.17.0.0/16  |
| vpc-euw1-dev-cell3001  | dev         | 10.17.16.0/20  |                        |

### TGW ASN for euw1

Per `specs/DESIGN.md`: euw1 ASN = `64515`

### Security Group Supernet CIDRs

| env  | region | env_supernet_cidr |
|------|--------|-------------------|
| dev  | euw1   | 10.17.0.0/16      |
| prod | euw1   | 10.16.0.0/16      |

### State File Keys (S3 bucket: `dmac-bootstrap-tfstate`, backend region: `eu-west-2`)

| Directory                              | State Key                                        |
|----------------------------------------|--------------------------------------------------|
| `envs/networking/euw1/tgw/`            | `env-networking/euw1-tgw/terraform.tfstate`      |
| `envs/networking/euw1/tgw-vpc-atts/`  | `env-networking/euw1-tgw-vpc-atts/terraform.tfstate` |
| `envs/dev/euw1/cell3000/`              | `env-dev/euw1/cell3000/terraform.tfstate`        |
| `envs/dev/euw1/cell3001/`              | `env-dev/euw1/cell3001/terraform.tfstate`        |
| `envs/prod/euw1/cell2000/`             | `env-prod/euw1/cell2000/terraform.tfstate`       |
| `envs/prod/euw1/cell2001/`             | `env-prod/euw1/cell2001/terraform.tfstate`       |
| `envs/networking/global/tgw-peering/` | `env-networking/global-tgw-peering/terraform.tfstate` |

### TGW Peering

AWS TGW Peering between euw2 and euw1 is a two-sided operation:
- The **requester** side creates `aws_ec2_transit_gateway_peering_attachment` in euw2.
- The **accepter** side accepts it in euw1 using `aws_ec2_transit_gateway_peering_attachment_accepter`.
- After acceptance, static routes must be added to both TGW route tables (euw2 TGW → 10.16.0.0/12 via peering attachment; euw1 TGW → 10.0.0.0/12 via peering attachment).
- The `envs/networking/global/tgw-peering/` root reads euw2 TGW state and euw1 TGW state via `terraform_remote_state`.

### Naming Convention

All new resources follow the project naming convention from `CLAUDE.md` and `specs/DESIGN.md`.

---

## Step 1 — Create `envs/networking/euw1/tgw/`

Mirror `envs/networking/euw2/tgw/` with euw1 values.

### `backend.tf`

```hcl
terraform {
  backend "s3" {
    region       = "eu-west-2"
    bucket       = "dmac-bootstrap-tfstate"
    key          = "env-networking/euw1-tgw/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
```

### `locals.tf`

```hcl
locals {
  region          = "eu-west-1"
  region_short    = "euw1"
  amazon_side_asn = 64515

  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment          = "networking-tgw"
    region               = local.region
    region_short         = local.region_short
  }
}
```

### `providers.tf`

```hcl
terraform {
  required_version = ">= 1.2.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.31.0"
    }
  }
}

provider "aws" {
  region = local.region
}
```

### `tgw.tf`

```hcl
module "tgw" {
  source = "../../../../modules/create-tgw"

  region          = local.region
  region_short    = local.region_short
  amazon_side_asn = local.amazon_side_asn
  default_tags    = local.default_tags
}
```

### `outputs.tf`

```hcl
output "transit_gateway" {
  description = "Transit Gateway resource"
  value       = module.tgw.transit_gateway
}

output "route_table_prod" {
  description = "Production route table"
  value       = module.tgw.route_table_prod
}

output "route_table_dev" {
  description = "Development route table"
  value       = module.tgw.route_table_dev
}

output "route_table_shared" {
  description = "Shared services route table"
  value       = module.tgw.route_table_shared
}
```

---

## Step 2 — Create `envs/dev/euw1/cell3000/`

Mirror `envs/dev/euw2/cell1000/` with euw1/cell3000 values.

### `backend.tf`

```hcl
terraform {
  backend "s3" {
    region       = "eu-west-2"
    bucket       = "dmac-bootstrap-tfstate"
    key          = "env-dev/euw1/cell3000/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
```

### `locals.tf`

```hcl
locals {
  region       = "eu-west-1"
  region_short = "euw1"
  environment  = "dev"
  cell_name    = "cell3000"
  vpc_name     = "${local.region_short}-${local.environment}-${local.cell_name}"
  project_root = pathexpand("~/repos/aws-global-network")

  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment          = local.environment
    region               = local.region
    region_short         = local.region_short
    cell_name            = local.cell_name
  }

  private_subnets = {
    priv-0 = {
      az          = "${local.region}a"
      cidr        = "10.17.0.0/24"
      nat_gateway = true
    }
    priv-1 = {
      az          = "${local.region}b"
      cidr        = "10.17.1.0/24"
      nat_gateway = true
    }
    priv-2 = {
      az          = "${local.region}c"
      cidr        = "10.17.2.0/24"
      nat_gateway = true
    }
  }
}
```

### `providers.tf`

```hcl
terraform {
  required_version = ">= 1.2.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.31.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.70.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
  }
}

provider "aws" {
  region = local.region
}
```

### `keypair.tf`

```hcl
data "aws_key_pair" "this" {
  key_name = "kp-${local.region_short}-${local.environment}"
}
```

### `vpc.tf`

```hcl
module "vpc-main" {
  source = "../../../../modules/create-vpc/"

  region       = local.region
  region_short = local.region_short
  environment  = local.environment
  vpc_name     = local.vpc_name
  cell_name    = local.cell_name
  vpc_cidr     = "10.17.0.0/20"
  default_tags = local.default_tags

  private_subnets = {
    priv-0 = {
      az          = "${local.region}a"
      cidr        = "10.17.0.0/24"
      nat_gateway = true
    }
    priv-1 = {
      az          = "${local.region}b"
      cidr        = "10.17.1.0/24"
      nat_gateway = true
    }
    priv-2 = {
      az          = "${local.region}c"
      cidr        = "10.17.2.0/24"
      nat_gateway = true
    }
  }

  public_subnets = {
    pub-0 = {
      az          = "${local.region}a"
      cidr        = "10.17.10.0/24"
      nat_gateway = false
    }
    pub-1 = {
      az          = "${local.region}b"
      cidr        = "10.17.11.0/24"
      nat_gateway = false
    }
    pub-2 = {
      az          = "${local.region}c"
      cidr        = "10.17.12.0/24"
      nat_gateway = false
    }
  }

  assign_generated_ipv6_cidr_block = "true"
}
```

### `security.tf`

```hcl
module "security" {
  source       = "../../../../modules/security"
  vpc_id       = module.vpc-main.vpc.id
  vpc_cidr     = module.vpc-main.vpc.cidr_block
  region_short = local.region_short
  environment  = local.environment
  cell_name    = local.cell_name
  default_tags = local.default_tags

  public_subnet_ids  = [for k, v in module.vpc-main.public_subnets : v.id]
  private_subnet_ids = [for k, v in module.vpc-main.private_subnets : v.id]

  # Allow all dev euw1 cells (10.17.0.0/16) to communicate via TGW
  env_supernet_cidr = "10.17.0.0/16"
}
```

### `ec2s.tf`

```hcl
module "ec2" {
  source       = "../../../../modules/create-ec2"
  region       = local.region
  region_short = local.region_short
  environment  = local.environment
  vpc_id       = module.vpc-main.vpc.id
  vpc_name     = local.vpc_name
  cell_name    = local.cell_name
  default_tags = local.default_tags

  public_subnets  = module.vpc-main.public_subnets
  private_subnets = module.vpc-main.private_subnets
  key_pair_name   = data.aws_key_pair.this.key_name

  public_security_group_id  = module.security.bastion_security_group_id
  private_security_group_id = module.security.private_security_group_id
}
```

### `sec-groups.tf`

```hcl
# NOTE: Using VPC default security groups for now
# Phase 5 will implement custom security groups module
#
# Default SGs allow:
# - All outbound traffic
# - No inbound traffic (needs manual console access for SSH)
```

### `shared-vars.tf`

```hcl
# Global Variables, Symlinked to each env/region
## Global Vars


## Regional Vars
variable "region" {
  type        = string
  description = "Target Region to deploy the resources"
  default     = null
}

variable "region_short" {
  type        = string
  description = "(Shorter Version) Target Region to deploy the resources. ie. use1, use2, euw2, etc"
  default     = null
}

## Environment Vars
variable "environment" {
  type        = string
  description = "Target environment to deploy the resources. i.e prod, dev, stage, etc"
  default     = null
}
```

### `outputs.tf`

```hcl
output "vpc" {
  value       = module.vpc-main.vpc
  description = "VPC output with all attributes including id, cidr_block, name, and environment"
}

output "private_subnets_id" {
  value = {
    for subnet, attribute in module.vpc-main.private_subnets : subnet => {
      id        = attribute["id"]
      cidr_ipv4 = attribute["cidr_block"]
      cidr_ipv6 = attribute["ipv6_cidr_block"]
    }
  }
  description = "Private Subnets' ID and CIDR blocks"
}

output "public_subnets_id" {
  value = {
    for subnet, attribute in module.vpc-main.public_subnets : subnet => {
      id        = attribute["id"]
      cidr_ipv4 = attribute["cidr_block"]
      cidr_ipv6 = attribute["ipv6_cidr_block"]
    }
  }
  description = "Public Subnets' ID and CIDR blocks"
}

output "private_route_tables_id" {
  value       = { for route-table, attribute in module.vpc-main.private_route_tables : route-table => attribute["id"] }
  description = "Private Route Tables' ID"
}

output "nat_gateway_id" {
  value       = module.vpc-main.nat_gateway.nat_gateway_id
  description = "Regional NAT Gateway ID"
}

output "private_subnet_ids" {
  value       = module.vpc-main.private_subnet_ids
  description = "List of private subnet IDs (convenience output for remote state)"
}

output "public_subnet_ids" {
  value       = module.vpc-main.public_subnet_ids
  description = "List of public subnet IDs (convenience output for remote state)"
}

output "instances" {
  description = "EC2 instance names and their IPs for SSH access"
  value = {
    bastions = {
      for k, ip in module.ec2.bastion_public_ips :
      format("bastion-%s-%s-%s-%s", local.region_short, local.environment, k, local.cell_name) => ip
    }
    private_hosts = {
      for k, ip in module.ec2.private_instance_private_ips :
      format("private-%s-%s-%s-%s", local.region_short, local.environment, k, local.cell_name) => ip
    }
  }
}

output "ssh_key_path" {
  description = "Local path to the SSH private key for this cell"
  value       = "${local.project_root}/ssh-keys/${local.region_short}-${local.environment}.pem"
}
```

---

## Step 3 — Create `envs/dev/euw1/cell3001/`

Mirror Step 2 (cell3000) with the following differences:

| Field         | Value                                              |
|---------------|----------------------------------------------------|
| `cell_name`   | `cell3001`                                         |
| `vpc_cidr`    | `10.17.16.0/20`                                    |
| priv-0 cidr   | `10.17.16.0/24`                                    |
| priv-1 cidr   | `10.17.17.0/24`                                    |
| priv-2 cidr   | `10.17.18.0/24`                                    |
| pub-0 cidr    | `10.17.26.0/24`                                    |
| pub-1 cidr    | `10.17.27.0/24`                                    |
| pub-2 cidr    | `10.17.28.0/24`                                    |
| backend key   | `env-dev/euw1/cell3001/terraform.tfstate`          |

All other files are identical to cell3000.

---

## Step 4 — Create `envs/prod/euw1/cell2000/`

Mirror `envs/prod/euw2/cell0000/` with euw1/cell2000 values:

| Field              | Value                                                   |
|--------------------|---------------------------------------------------------|
| `region`           | `eu-west-1`                                             |
| `region_short`     | `euw1`                                                  |
| `environment`      | `prod`                                                  |
| `cell_name`        | `cell2000`                                              |
| `vpc_cidr`         | `10.16.0.0/20`                                          |
| priv-0 cidr        | `10.16.0.0/24`                                          |
| priv-1 cidr        | `10.16.1.0/24`                                          |
| priv-2 cidr        | `10.16.2.0/24`                                          |
| pub-0 cidr         | `10.16.10.0/24`                                         |
| pub-1 cidr         | `10.16.11.0/24`                                         |
| pub-2 cidr         | `10.16.12.0/24`                                         |
| `env_supernet_cidr`| `10.16.0.0/16`                                          |
| backend key        | `env-prod/euw1/cell2000/terraform.tfstate`              |

---

## Step 5 — Create `envs/prod/euw1/cell2001/`

Mirror Step 4 (cell2000) with the following differences:

| Field         | Value                                              |
|---------------|----------------------------------------------------|
| `cell_name`   | `cell2001`                                         |
| `vpc_cidr`    | `10.16.16.0/20`                                    |
| priv-0 cidr   | `10.16.16.0/24`                                    |
| priv-1 cidr   | `10.16.17.0/24`                                    |
| priv-2 cidr   | `10.16.18.0/24`                                    |
| pub-0 cidr    | `10.16.26.0/24`                                    |
| pub-1 cidr    | `10.16.27.0/24`                                    |
| pub-2 cidr    | `10.16.28.0/24`                                    |
| backend key   | `env-prod/euw1/cell2001/terraform.tfstate`         |

---

## Step 6 — Create `envs/networking/euw1/tgw-vpc-atts/`

Mirror `envs/networking/euw2/tgw-vpc-atts/` with euw1 values.

### `backend.tf`

```hcl
terraform {
  backend "s3" {
    region       = "eu-west-2"
    bucket       = "dmac-bootstrap-tfstate"
    key          = "env-networking/euw1-tgw-vpc-atts/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
```

### `locals.tf`

```hcl
locals {
  region       = "eu-west-1"
  region_short = "euw1"

  cell_mappings = {
    dev = {
      cell3000 = {
        state_key = "env-dev/euw1/cell3000/terraform.tfstate"
      }
      cell3001 = {
        state_key = "env-dev/euw1/cell3001/terraform.tfstate"
      }
    }
    prod = {
      cell2000 = {
        state_key = "env-prod/euw1/cell2000/terraform.tfstate"
      }
      cell2001 = {
        state_key = "env-prod/euw1/cell2001/terraform.tfstate"
      }
    }
  }

  current_environment = var.target_environment
  tgw_supernet_cidr   = "10.0.0.0/8"

  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment          = "networking-tgw-vpc-atts"
    region               = local.region
    region_short         = local.region_short
  }
}
```

### `providers.tf`

```hcl
terraform {
  required_version = ">= 1.2.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.31.0"
    }
  }
}

provider "aws" {
  region = local.region
}
```

### `variables.tf`

```hcl
variable "target_environment" {
  type        = string
  description = "Target environment for VPC attachments (dev, prod)"
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.target_environment)
    error_message = "Environment must be either 'dev' or 'prod'."
  }
}

variable "backend_bucket" {
  type        = string
  description = "S3 bucket name for Terraform remote state"
  default     = "dmac-bootstrap-tfstate"
}
```

### `data.tf`

```hcl
# Read TGW state
data "terraform_remote_state" "tgw" {
  backend = "s3"
  config = {
    bucket = var.backend_bucket
    key    = "env-networking/euw1-tgw/terraform.tfstate"
    region = "eu-west-2"
  }
}

# Dynamic VPC state data sources for each cell
data "terraform_remote_state" "vpc_states" {
  for_each = local.cell_mappings[local.current_environment]
  backend  = "s3"
  config = {
    bucket = var.backend_bucket
    key    = each.value.state_key
    region = "eu-west-2"
  }
}
```

### `vpc-attachments.tf`

```hcl
module "vpc_attachments" {
  for_each = local.cell_mappings[local.current_environment]
  source   = "../../../../modules/create-tgw-vpc-attachment"

  transit_gateway_id = data.terraform_remote_state.tgw.outputs.transit_gateway.id
  vpc_id             = data.terraform_remote_state.vpc_states[each.key].outputs.vpc.id
  subnet_ids         = data.terraform_remote_state.vpc_states[each.key].outputs.private_subnet_ids

  transit_gateway_route_table_id = try(
    data.terraform_remote_state.vpc_states[each.key].outputs.vpc.environment == "prod" ?
    data.terraform_remote_state.tgw.outputs.route_table_prod.id :
    data.terraform_remote_state.tgw.outputs.route_table_dev.id,
    data.terraform_remote_state.tgw.outputs.route_table_dev.id
  )

  environment  = try(data.terraform_remote_state.vpc_states[each.key].outputs.vpc.environment, "dev")
  region_short = local.region_short
  vpc_name     = try(data.terraform_remote_state.vpc_states[each.key].outputs.vpc.name, "main")

  private_route_table_ids = data.terraform_remote_state.vpc_states[each.key].outputs.private_route_tables_id
  tgw_supernet_cidr       = local.tgw_supernet_cidr

  default_tags = merge(local.default_tags, {
    cell = each.key
  })
}
```

### `outputs.tf`

```hcl
output "vpc_attachments" {
  description = "VPC attachment details for all cells"
  value       = module.vpc_attachments
}

output "attachment_ids" {
  description = "VPC attachment IDs for all cells"
  value       = { for k, v in module.vpc_attachments : k => v.attachment_id }
}

output "attachment_count" {
  description = "Number of VPC attachments created"
  value       = length(module.vpc_attachments)
}
```

---

## Step 7 — Create `envs/networking/global/tgw-peering/`

This module creates the TGW Peering Attachment from euw2 to euw1 and accepts it, then adds static routes to both TGWs so that inter-region traffic flows correctly.

AWS TGW peering is cross-region, so the provider block requires two aliased AWS providers.

### `backend.tf`

```hcl
terraform {
  backend "s3" {
    region       = "eu-west-2"
    bucket       = "dmac-bootstrap-tfstate"
    key          = "env-networking/global-tgw-peering/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
```

### `locals.tf`

```hcl
locals {
  euw2_region       = "eu-west-2"
  euw2_region_short = "euw2"
  euw1_region       = "eu-west-1"
  euw1_region_short = "euw1"

  # euw2 TGW routes → euw1 CIDR block (10.16.0.0/12)
  euw1_supernet_cidr = "10.16.0.0/12"
  # euw1 TGW routes → euw2 CIDR block (10.0.0.0/12)
  euw2_supernet_cidr = "10.0.0.0/12"

  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment          = "networking-tgw-peering"
  }
}
```

### `providers.tf`

```hcl
terraform {
  required_version = ">= 1.2.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.31.0"
    }
  }
}

# Requester side (euw2 - where the peering attachment is created)
provider "aws" {
  alias  = "euw2"
  region = local.euw2_region
}

# Accepter side (euw1 - where the peering attachment is accepted)
provider "aws" {
  alias  = "euw1"
  region = local.euw1_region
}
```

### `variables.tf`

```hcl
variable "backend_bucket" {
  type        = string
  description = "S3 bucket name for Terraform remote state"
  default     = "dmac-bootstrap-tfstate"
}
```

### `data.tf`

```hcl
# Read euw2 TGW state
data "terraform_remote_state" "tgw_euw2" {
  backend = "s3"
  config = {
    bucket = var.backend_bucket
    key    = "env-networking/euw2-tgw/terraform.tfstate"
    region = local.euw2_region
  }
}

# Read euw1 TGW state
data "terraform_remote_state" "tgw_euw1" {
  backend = "s3"
  config = {
    bucket = var.backend_bucket
    key    = "env-networking/euw1-tgw/terraform.tfstate"
    region = local.euw2_region
  }
}
```

### `tgw-peering.tf`

```hcl
# Create peering attachment from euw2 TGW (requester)
resource "aws_ec2_transit_gateway_peering_attachment" "this" {
  provider = aws.euw2

  transit_gateway_id      = data.terraform_remote_state.tgw_euw2.outputs.transit_gateway.id
  peer_transit_gateway_id = data.terraform_remote_state.tgw_euw1.outputs.transit_gateway.id
  peer_region             = local.euw1_region

  tags = merge(local.default_tags, {
    Name = "tgw-pcx-${local.euw2_region_short}-${local.euw1_region_short}"
  })
}

# Accept peering attachment from euw1 TGW (accepter)
resource "aws_ec2_transit_gateway_peering_attachment_accepter" "this" {
  provider = aws.euw1

  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.this.id

  tags = merge(local.default_tags, {
    Name = "tgw-pcx-${local.euw1_region_short}-${local.euw2_region_short}"
  })
}

# Static route on euw2 TGW: traffic to euw1 CIDR (10.16.0.0/12) → peering attachment
resource "aws_ec2_transit_gateway_route" "euw2_to_euw1_prod" {
  provider = aws.euw2

  destination_cidr_block         = local.euw1_supernet_cidr
  transit_gateway_route_table_id = data.terraform_remote_state.tgw_euw2.outputs.route_table_prod.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.this.id
}

resource "aws_ec2_transit_gateway_route" "euw2_to_euw1_dev" {
  provider = aws.euw2

  destination_cidr_block         = local.euw1_supernet_cidr
  transit_gateway_route_table_id = data.terraform_remote_state.tgw_euw2.outputs.route_table_dev.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.this.id
}

# Static route on euw1 TGW: traffic to euw2 CIDR (10.0.0.0/12) → peering attachment
resource "aws_ec2_transit_gateway_route" "euw1_to_euw2_prod" {
  provider = aws.euw1

  destination_cidr_block         = local.euw2_supernet_cidr
  transit_gateway_route_table_id = data.terraform_remote_state.tgw_euw1.outputs.route_table_prod.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.this.id
}

resource "aws_ec2_transit_gateway_route" "euw1_to_euw2_dev" {
  provider = aws.euw1

  destination_cidr_block         = local.euw2_supernet_cidr
  transit_gateway_route_table_id = data.terraform_remote_state.tgw_euw1.outputs.route_table_dev.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.this.id
}
```

### `outputs.tf`

```hcl
output "peering_attachment_id" {
  description = "TGW Peering Attachment ID"
  value       = aws_ec2_transit_gateway_peering_attachment.this.id
}

output "peering_attachment_state" {
  description = "TGW Peering Attachment state"
  value       = aws_ec2_transit_gateway_peering_attachment.this.state
}
```

---

## Step 8 — Deploy Script

The `scripts/deploy.sh` already supports Phase 3 for TGW Peering Attachments by discovering `envs/networking/global/tgw-peering/` via `discover_tgw_peering`. No changes to `deploy.sh` are required.

Update `scripts/destroy.sh` to add a Phase 4 destroy step for TGW Peering (destroy peering before TGW-VPC attachments). Verify destroy order is the reverse of deploy:

- Phase 4: TGW Peering
- Phase 3: TGW-VPC Attachments
- Phase 2: VPC Cells + TGWs
- Phase 1: Keypairs

---

## Architecture

```
envs/networking/euw1/tgw/                   (Step 1 — new)
  backend.tf
  locals.tf      # region=eu-west-1, asn=64515
  providers.tf
  tgw.tf
  outputs.tf

envs/dev/euw1/cell3000/                     (Step 2 — new)
  backend.tf     # key: env-dev/euw1/cell3000/terraform.tfstate
  locals.tf      # cell3000, 10.17.0.0/20
  providers.tf
  keypair.tf     # data source: kp-euw1-dev
  vpc.tf
  security.tf    # env_supernet_cidr = 10.17.0.0/16
  ec2s.tf
  sec-groups.tf
  shared-vars.tf
  outputs.tf

envs/dev/euw1/cell3001/                     (Step 3 — new)
  (same as cell3000, cell_name=cell3001, cidr=10.17.16.0/20)

envs/prod/euw1/cell2000/                    (Step 4 — new)
  backend.tf     # key: env-prod/euw1/cell2000/terraform.tfstate
  locals.tf      # cell2000, 10.16.0.0/20
  providers.tf
  keypair.tf     # data source: kp-euw1-prod
  vpc.tf
  security.tf    # env_supernet_cidr = 10.16.0.0/16
  ec2s.tf
  sec-groups.tf
  shared-vars.tf
  outputs.tf

envs/prod/euw1/cell2001/                    (Step 5 — new)
  (same as cell2000, cell_name=cell2001, cidr=10.16.16.0/20)

envs/networking/euw1/tgw-vpc-atts/          (Step 6 — new)
  backend.tf
  locals.tf      # cell3000/3001 (dev), cell2000/2001 (prod)
  providers.tf
  variables.tf
  data.tf
  vpc-attachments.tf
  outputs.tf

envs/networking/global/tgw-peering/         (Step 7 — new)
  backend.tf
  locals.tf      # euw2 + euw1 peering config
  providers.tf   # dual-provider: aws.euw2 + aws.euw1
  variables.tf
  data.tf
  tgw-peering.tf # peering attachment + accepter + static routes
  outputs.tf
```

---

## Deployment Order

The deploy script handles ordering automatically via phases:

```
Phase 0 (parallel) : envs/dev/euw1/keypair/, envs/prod/euw1/keypair/
                     (already exist from spec 05)

Phase 1 (parallel) : envs/networking/euw1/tgw/
                     envs/dev/euw1/cell3000/
                     envs/dev/euw1/cell3001/
                     envs/prod/euw1/cell2000/
                     envs/prod/euw1/cell2001/
                     (plus all existing euw2 resources)

Wait 30s for TGW propagation

Phase 2 (parallel) : envs/networking/euw1/tgw-vpc-atts/ (dev run, then prod run)
                     (plus existing euw2 tgw-vpc-atts)

Phase 3 (sequential): envs/networking/global/tgw-peering/
```

---

## Validation

Run after creating/editing each directory:

```bash
terraform fmt --recursive $PROJECT_NAME
terraform -chdir=envs/networking/euw1/tgw validate
terraform -chdir=envs/dev/euw1/cell3000 validate
terraform -chdir=envs/dev/euw1/cell3001 validate
terraform -chdir=envs/prod/euw1/cell2000 validate
terraform -chdir=envs/prod/euw1/cell2001 validate
terraform -chdir=envs/networking/euw1/tgw-vpc-atts validate
terraform -chdir=envs/networking/global/tgw-peering validate
tflint --recursive --config=tools/.tflint.hcl
```

---

## Connectivity Test

After full deployment, verify inter-region routing works:

1. SSH to bastion in euw1 cell3000: `ssh -i ssh-keys/euw1-dev.pem ubuntu@<bastion-public-ip>`
2. From the bastion, SSH to the private host in euw1 cell3000 via private IP.
3. From the private host, ping a private IP in euw2 cell1000 (e.g. `10.1.0.x`):
   ```bash
   ping 10.1.0.x  # should succeed via TGW → peering → euw2 TGW
   ```
4. Repeat from an euw2 private host to an euw1 private host (e.g. `10.17.0.x`).

---

## Files to Create

| Step | File | Action |
|------|------|--------|
| 1 | `envs/networking/euw1/tgw/backend.tf` | Create |
| 1 | `envs/networking/euw1/tgw/locals.tf` | Create |
| 1 | `envs/networking/euw1/tgw/providers.tf` | Create |
| 1 | `envs/networking/euw1/tgw/tgw.tf` | Create |
| 1 | `envs/networking/euw1/tgw/outputs.tf` | Create |
| 2 | `envs/dev/euw1/cell3000/backend.tf` | Create |
| 2 | `envs/dev/euw1/cell3000/locals.tf` | Create |
| 2 | `envs/dev/euw1/cell3000/providers.tf` | Create |
| 2 | `envs/dev/euw1/cell3000/keypair.tf` | Create |
| 2 | `envs/dev/euw1/cell3000/vpc.tf` | Create |
| 2 | `envs/dev/euw1/cell3000/security.tf` | Create |
| 2 | `envs/dev/euw1/cell3000/ec2s.tf` | Create |
| 2 | `envs/dev/euw1/cell3000/sec-groups.tf` | Create |
| 2 | `envs/dev/euw1/cell3000/shared-vars.tf` | Create |
| 2 | `envs/dev/euw1/cell3000/outputs.tf` | Create |
| 3 | `envs/dev/euw1/cell3001/` (all files) | Create (same as cell3000, different CIDR/cell_name) |
| 4 | `envs/prod/euw1/cell2000/` (all files) | Create |
| 5 | `envs/prod/euw1/cell2001/` (all files) | Create |
| 6 | `envs/networking/euw1/tgw-vpc-atts/backend.tf` | Create |
| 6 | `envs/networking/euw1/tgw-vpc-atts/locals.tf` | Create |
| 6 | `envs/networking/euw1/tgw-vpc-atts/providers.tf` | Create |
| 6 | `envs/networking/euw1/tgw-vpc-atts/variables.tf` | Create |
| 6 | `envs/networking/euw1/tgw-vpc-atts/data.tf` | Create |
| 6 | `envs/networking/euw1/tgw-vpc-atts/vpc-attachments.tf` | Create |
| 6 | `envs/networking/euw1/tgw-vpc-atts/outputs.tf` | Create |
| 7 | `envs/networking/global/tgw-peering/backend.tf` | Create |
| 7 | `envs/networking/global/tgw-peering/locals.tf` | Create |
| 7 | `envs/networking/global/tgw-peering/providers.tf` | Create |
| 7 | `envs/networking/global/tgw-peering/variables.tf` | Create |
| 7 | `envs/networking/global/tgw-peering/data.tf` | Create |
| 7 | `envs/networking/global/tgw-peering/tgw-peering.tf` | Create |
| 7 | `envs/networking/global/tgw-peering/outputs.tf` | Create |
| 9 | `specs/index.md` | Edit (mark 06 as Complete) |

---

## Implementation Status

| Item | Status |
|------|--------|
| `envs/networking/euw1/tgw/` — all files | Complete |
| `envs/dev/euw1/cell3000/` — all files | Complete |
| `envs/dev/euw1/cell3001/` — all files | Complete |
| `envs/prod/euw1/cell2000/` — all files | Complete |
| `envs/prod/euw1/cell2001/` — all files | Complete |
| `envs/networking/euw1/tgw-vpc-atts/` — all files | Complete |
| `envs/networking/global/tgw-peering/` — all files | Complete |
| All directories pass `terraform validate` | Complete |
| All directories pass `tflint` | Complete |
| `terraform apply` — full deployment to AWS | Complete |
| Connectivity test euw1 → euw2 (ping) | Complete |
| Connectivity test euw2 → euw1 (ping) | Complete |
| `specs/index.md` updated | Complete |

## What Was Actually Built

The following directories were created and applied to AWS:

```
envs/networking/euw1/tgw/           — TGW ASN 64515, prod/dev/shared route tables
envs/dev/euw1/cell3000/             — VPC 10.17.0.0/20, 3 priv + 3 pub subnets, 1 NGW, bastion + private EC2
envs/dev/euw1/cell3001/             — VPC 10.17.16.0/20, same pattern as cell3000
envs/prod/euw1/cell2000/            — VPC 10.16.0.0/20, 3 priv + 3 pub subnets, 1 NGW, bastion + private EC2
envs/prod/euw1/cell2001/            — VPC 10.16.16.0/20, same pattern as cell2000
envs/networking/euw1/tgw-vpc-atts/  — TGW-VPC attachments for all 4 euw1 cells (dev + prod)
envs/networking/global/tgw-peering/ — TGW Peering Attachment euw2↔euw1 + static routes (dual-provider)
```

The `scripts/deploy.sh` Phase 3 (TGW Peering) and `scripts/destroy.sh` Phase 1 (TGW Peering teardown) were already in place from prior work. The deploy and destroy scripts were updated to discover the new euw1 directories automatically via the existing region discovery logic.
