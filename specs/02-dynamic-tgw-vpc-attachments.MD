# Spec 02 - Dynamic TGW-VPC Attachments and Remote State Refactoring

## Overview

Refactored the `envs/networking/euw2/tgw-vpc-atts/` environment to use dynamic, data-driven VPC attachment creation instead of one hardcoded module call per VPC. A `cell_mappings` local drives `for_each` on both the remote state data sources and the attachment module, making it trivial to add or remove cells without touching the attachment logic.

The VPC module and environment outputs were also extended with simplified scalar outputs so that remote state consumers no longer need complex for-loops to extract IDs.

The `modules/create-tgw-vpc-attachment` module was extended to include VPC-side routes (`aws_route.tgw`) that add a 10.0.0.0/8 supernet route to each private subnet route table, routing east-west traffic through the TGW.

**Status**: Fully implemented and merged to `feature/inter-vpc-routing`. Not yet applied to AWS.

---

## Goals

1. Replace per-cell hardcoded `module "attachment_<cell>"` blocks with a single `for_each`-driven module call.
2. Drive `for_each` from a structured `cell_mappings` local — one entry per cell, keyed by cell name.
3. Read VPC state dynamically using `data "terraform_remote_state" "vpc_states"` with `for_each`.
4. Automatically assign the correct TGW route table (dev vs. prod) based on the `environment` output from each VPC's remote state.
5. Expose `environment` and `vpc_name` from VPC remote state instead of hardcoding them in the attachment caller.
6. Add simplified scalar outputs (`vpc_id`, `private_subnet_ids`, `public_subnet_ids`) to the VPC module and the `dev/euw2/cell1000` environment so remote state consumers have clean, direct access.
7. Add VPC-side routes to the TGW supernet (10.0.0.0/8) in each private subnet route table within the `create-tgw-vpc-attachment` module.

---

## Changes Implemented

### `modules/create-vpc/outputs.tf`

Added three new simplified scalar outputs alongside the existing full-object outputs:

```hcl
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = [for k, v in aws_subnet.private : v.id]
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = [for k, v in aws_subnet.public : v.id]
}
```

The existing complex object outputs (`vpc`, `private_subnets`, `public_subnets`, `private_route_tables`, `nat_gateway`) are unchanged to preserve backward compatibility.

**File**: `modules/create-vpc/outputs.tf`

---

### `envs/dev/euw2/cell1000/outputs.tf`

Added `private_subnet_ids` and `public_subnet_ids` scalar outputs that proxy from the module:

```hcl
output "private_subnet_ids" {
  value       = module.vpc-main.private_subnet_ids
  description = "List of private subnet IDs (convenience output for remote state)"
}

output "public_subnet_ids" {
  value       = module.vpc-main.public_subnet_ids
  description = "List of public subnet IDs (convenience output for remote state)"
}
```

The `vpc` output already exposes `name` and `environment` via the module's merged output, so those attributes are available to remote state consumers at `outputs.vpc.name` and `outputs.vpc.environment`.

**File**: `envs/dev/euw2/cell1000/outputs.tf`

---

### `envs/networking/euw2/tgw-vpc-atts/locals.tf`

Introduced a structured `cell_mappings` local that maps each environment to its cells. Each cell entry only requires the S3 state key — environment and `vpc_name` are read from the remote state itself.

```hcl
cell_mappings = {
  dev = {
    cell1000 = {
      state_key = "env-dev/euw2/cell1000/terraform.tfstate"
    }
    # cell1001 = { state_key = "..." }  # Uncomment when cell1001 exists
  }
  prod = {
    cell1000 = {
      state_key = "env-prod/euw2/cell1000/terraform.tfstate"
    }
    cell0001 = {
      state_key = "env-prod/euw2/cell0001/terraform.tfstate"
    }
  }
}

current_environment = var.target_environment
```

Also added `tgw_supernet_cidr = "10.0.0.0/8"` local for the VPC-side route supernet.

**File**: `envs/networking/euw2/tgw-vpc-atts/locals.tf`

---

### `envs/networking/euw2/tgw-vpc-atts/variables.tf`

Added two input variables:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `target_environment` | `string` | `"dev"` | Target environment for VPC attachments (dev or prod). Validated with `contains(["dev", "prod"], ...)`. |
| `backend_bucket` | `string` | `"dmac-bootstrap-tfstate"` | S3 bucket name for Terraform remote state. |

**File**: `envs/networking/euw2/tgw-vpc-atts/variables.tf`

---

### `envs/networking/euw2/tgw-vpc-atts/data.tf`

Replaced the single hardcoded `dev_vpc` data source with a dynamic `for_each` data source:

```hcl
# Read TGW state (unchanged)
data "terraform_remote_state" "tgw" {
  backend = "s3"
  config = {
    bucket = var.backend_bucket
    key    = "env-networking/euw2-tgw/terraform.tfstate"
    region = local.region
  }
}

# Dynamic VPC state data sources for each cell
data "terraform_remote_state" "vpc_states" {
  for_each = local.cell_mappings[local.current_environment]
  backend  = "s3"
  config = {
    bucket = var.backend_bucket
    key    = each.value.state_key
    region = local.region
  }
}
```

**File**: `envs/networking/euw2/tgw-vpc-atts/data.tf`

---

### `envs/networking/euw2/tgw-vpc-atts/vpc-attachments.tf`

Replaced per-cell module blocks with a single `for_each` module call. Added `private_route_table_ids` and `tgw_supernet_cidr` inputs to drive the VPC-side TGW routes:

```hcl
module "vpc_attachments" {
  for_each = local.cell_mappings[local.current_environment]
  source   = "../../../../modules/create-tgw-vpc-attachment"

  transit_gateway_id = data.terraform_remote_state.tgw.outputs.transit_gateway.id
  vpc_id             = data.terraform_remote_state.vpc_states[each.key].outputs.vpc.id
  subnet_ids         = data.terraform_remote_state.vpc_states[each.key].outputs.private_subnet_ids

  # Dynamic route table assignment based on VPC environment output
  # Dev VPCs -> dev route table, Prod VPCs -> prod route table
  transit_gateway_route_table_id = try(
    data.terraform_remote_state.vpc_states[each.key].outputs.vpc.environment == "prod" ?
    data.terraform_remote_state.tgw.outputs.route_table_prod.id :
    data.terraform_remote_state.tgw.outputs.route_table_dev.id,
    data.terraform_remote_state.tgw.outputs.route_table_dev.id  # Fallback to dev
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

**File**: `envs/networking/euw2/tgw-vpc-atts/vpc-attachments.tf`

---

### `envs/networking/euw2/tgw-vpc-atts/outputs.tf`

Updated outputs to reflect the `for_each` module shape:

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

**File**: `envs/networking/euw2/tgw-vpc-atts/outputs.tf`

---

### `modules/create-tgw-vpc-attachment/vpc-attachment.tf`

Extended the module to create VPC-side routes that send the TGW supernet from each private subnet route table to the TGW, enabling east-west traffic between cells and regions:

```hcl
# VPC-side route: send the TGW supernet from each private subnet route table
# to the TGW, enabling east-west traffic between cells and regions.
resource "aws_route" "tgw" {
  for_each = var.private_route_table_ids

  route_table_id         = each.value
  destination_cidr_block = var.tgw_supernet_cidr
  transit_gateway_id     = var.transit_gateway_id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}
```

**File**: `modules/create-tgw-vpc-attachment/vpc-attachment.tf`

---

### `modules/create-tgw-vpc-attachment/variables.tf`

Added two new optional variables to support the VPC-side routes:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `private_route_table_ids` | `map(string)` | `{}` | Map of private route table IDs (key -> rtb-id) to add a TGW supernet route to. |
| `tgw_supernet_cidr` | `string` | `"10.0.0.0/8"` | Supernet CIDR routed to the TGW from each private subnet route table. |

**File**: `modules/create-tgw-vpc-attachment/variables.tf`

---

## Architecture

```
envs/networking/euw2/tgw-vpc-atts/
  locals.tf          # cell_mappings{dev{cell1000...}, prod{cell1000, cell0001...}}, tgw_supernet_cidr
  variables.tf       # target_environment (dev|prod), backend_bucket
  data.tf            # tgw remote state + for_each vpc_states remote state
  vpc-attachments.tf # single for_each module "vpc_attachments" with route table IDs
  outputs.tf         # vpc_attachments map, attachment_ids map, attachment_count

modules/create-tgw-vpc-attachment/
  vpc-attachment.tf  # TGW attachment + route table association/propagation + aws_route.tgw
  variables.tf       # includes private_route_table_ids, tgw_supernet_cidr
```

### Data Flow

```
var.target_environment
    |
    v
local.cell_mappings[current_environment]  ──► data.terraform_remote_state.vpc_states (for_each)
    |                                               |
    |                                               v
    └──────────────────────────────────────────► module.vpc_attachments (for_each)
                                                    |
                                              outputs.vpc.environment
                                                    |
                                                    v
                                       TGW route table selection
                                       (dev RT or prod RT)
                                                    |
                                                    v
                                       aws_route.tgw (for_each over private_route_table_ids)
                                       destination: 10.0.0.0/8 -> TGW
```

---

## How to Add a New Cell

1. Deploy the new VPC cell under `envs/dev/euw2/<cell_name>/` or `envs/prod/euw2/<cell_name>/`.
2. Add an entry to `cell_mappings` in `envs/networking/euw2/tgw-vpc-atts/locals.tf`:

```hcl
dev = {
  cell1000 = { state_key = "env-dev/euw2/cell1000/terraform.tfstate" }
  cell1001 = { state_key = "env-dev/euw2/cell1001/terraform.tfstate" }  # New
}
```

3. Run `terraform apply` in `envs/networking/euw2/tgw-vpc-atts/`. The new attachment and VPC-side routes are created automatically.

---

## Implementation Status

| Item | Status |
|------|--------|
| `modules/create-vpc/outputs.tf` — scalar outputs | Complete |
| `envs/dev/euw2/cell1000/outputs.tf` — scalar outputs | Complete |
| `envs/networking/euw2/tgw-vpc-atts/locals.tf` — cell_mappings + tgw_supernet_cidr | Complete |
| `envs/networking/euw2/tgw-vpc-atts/variables.tf` — new vars | Complete |
| `envs/networking/euw2/tgw-vpc-atts/data.tf` — dynamic for_each | Complete |
| `envs/networking/euw2/tgw-vpc-atts/vpc-attachments.tf` — for_each module with route inputs | Complete |
| `envs/networking/euw2/tgw-vpc-atts/outputs.tf` — updated outputs | Complete |
| `modules/create-tgw-vpc-attachment/vpc-attachment.tf` — aws_route.tgw VPC-side routes | Complete |
| `modules/create-tgw-vpc-attachment/variables.tf` — private_route_table_ids, tgw_supernet_cidr | Complete |
| All modules pass `terraform validate` | Complete |
| `tgw-vpc-atts` directory passes `tflint` (zero warnings) | Complete |
| Apply to AWS (terraform apply) | Not started |
| Test inter-VPC connectivity through TGW | Not started |

---

## Next Steps

1. Run `terraform apply` in `envs/networking/euw2/tgw-vpc-atts/` with `-var target_environment=dev` to create the dev cell1000 attachment and VPC-side routes.
2. Test inter-VPC connectivity through TGW between cells.
3. When prod cells are deployed, run `terraform apply` with `-var target_environment=prod`.
