# Spec 05 - Create SSH Keypairs for dev/euw2 and prod/euw2

## Overview

Create standalone SSH key pair environments for eu-west-2 (`envs/dev/euw2/keypair/` and `envs/prod/euw2/keypair/`) using the `create-key-pair` module. This aligns euw2 with the euw1 pattern where keypairs have their own Terraform root with independent state, enabling the deploy script's Phase 0 to discover and deploy them before VPC cells.

Additionally, remove inline keypair creation from all euw2 cells (replace `module "key_pair"` with `data "aws_key_pair"` lookups), fix the backend region bug in euw1 keypair directories, and update `scripts/deploy.sh` Phase 1 to deploy all VPC cells fully in parallel now that keypairs are created in Phase 0.

**Status**: In progress

---

## Goals

1. Create `envs/dev/euw2/keypair/` — standalone keypair environment for dev eu-west-2.
2. Create `envs/prod/euw2/keypair/` — standalone keypair environment for prod eu-west-2.
3. Fix `envs/dev/euw1/keypair/backend.tf` — change backend region from `eu-west-1` to `eu-west-2`.
4. Fix `envs/prod/euw1/keypair/backend.tf` — change backend region from `eu-west-1` to `eu-west-2`.
5. Remove inline `module "key_pair"` from cells, replace with `data "aws_key_pair"` lookups.
6. Update `scripts/deploy.sh` Phase 1 — deploy all VPC cells in parallel (no sequential grouping).
7. Validate all keypair environments pass `terraform validate` and `tflint`.

---

## Context

### Current State

- **euw2 cells** (`cell1000`, `cell1001`, `cell0000`, `cell0001`): Each cell has an inline `keypair.tf` that calls the `create-key-pair` module. The keypair state lives inside each cell's state file.
- **euw1 keypairs** (`dev/euw1/keypair/`, `prod/euw1/keypair/`): Standalone directories exist but have a backend region bug (`eu-west-1` instead of `eu-west-2`).
- **Deploy script**: Phase 0 discovers `keypair/` directories under `envs/{dev,prod}/<region>/` and deploys them before VPC cells.

### Key Pair Naming Convention

The module generates keys named `kp-{region_short}-{environment}`:
- `kp-euw2-dev` — dev eu-west-2
- `kp-euw2-prod` — prod eu-west-2

Private keys are saved to `ssh-keys/{region_short}-{environment}.pem` (e.g. `ssh-keys/euw2-dev.pem`).

### Important Note

Since keypairs have not been deployed to AWS yet, the inline `module "key_pair"` in cells was replaced with `data "aws_key_pair"` lookups. Cells now reference the key by name (`kp-{region_short}-{environment}`) rather than creating it. The standalone keypair directories handle creation.

Cell1001 and cell0001 already used the data source pattern. Cell1000 and cell0000 were updated.

---

##  1 — Create `envs/dev/euw2/keypair/`

### `backend.tf`

```hcl
# A backend block cannot refer to named values (like input variables, locals, or data source attributes).
terraform {
  backend "s3" {
    region       = "eu-west-2"
    bucket       = "dmac-bootstrap-tfstate"
    key          = "env-dev/euw2/keypair/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
```

### `locals.tf`

```hcl
locals {
  region       = "eu-west-2"
  region_short = "euw2"
  environment  = "dev"
  project_root = pathexpand("~/repos/aws-global-network")

  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment          = local.environment
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
module "key_pair" {
  source       = "../../../../modules/create-key-pair"
  project_root = local.project_root
  region_short = local.region_short
  environment  = local.environment
  default_tags = local.default_tags
}
```

### `outputs.tf`

```hcl
output "key_pair_name" {
  description = "The AWS key pair name"
  value       = module.key_pair.key_pair_name
}

output "key_pair_path" {
  description = "Local path to the SSH private key"
  value       = module.key_pair.private_key_path
}
```

---

##  2 — Create `envs/prod/euw2/keypair/`

Identical to  1 with the following differences:

### `backend.tf`

- `key = "env-prod/euw2/keypair/terraform.tfstate"`

### `locals.tf`

- `environment = "prod"`

All other files are identical to the dev version.

---

##  3 — Fix euw1 backend region bugs

### `envs/dev/euw1/keypair/backend.tf`

Change `region = "eu-west-1"` → `region = "eu-west-2"` (bucket location, not deployment target).

### `envs/prod/euw1/keypair/backend.tf`

Change `region = "eu-west-1"` → `region = "eu-west-2"` (bucket location, not deployment target).

---

##  4 — Remove inline keypair creation from cells

Replace `module "key_pair"` with `data "aws_key_pair"` lookups in cells that still use inline creation.

### `envs/dev/euw2/cell1000/keypair.tf`

Create file with data source (was missing):

```hcl
data "aws_key_pair" "this" {
  key_name = "kp-${local.region_short}-${local.environment}"
}
```

### `envs/dev/euw2/cell1000/ec2s.tf`

Change `key_pair_name = module.key_pair.key_pair_name` → `key_pair_name = data.aws_key_pair.this.key_name`

### `envs/dev/euw2/cell1000/outputs.tf`

Change `ssh_key_path` value from `module.key_pair.private_key_path` → `"${local.project_root}/ssh-keys/${local.region_short}-${local.environment}.pem"`

### `envs/prod/euw2/cell0000/keypair.tf`

Replace `module "key_pair" { ... }` with:

```hcl
data "aws_key_pair" "this" {
  key_name = "kp-${local.region_short}-${local.environment}"
}
```

### `envs/prod/euw2/cell0000/ec2s.tf`

Change `key_pair_name = module.key_pair.key_pair_name` → `key_pair_name = data.aws_key_pair.this.key_name`

### `envs/prod/euw2/cell0000/outputs.tf`

Change `ssh_key_path` value from `module.key_pair.private_key_path` → `"${local.project_root}/ssh-keys/${local.region_short}-${local.environment}.pem"`

Note: `cell1001` and `cell0001` already use the data source pattern — no changes needed.

---

##  5 — Deploy script: fully parallel VPC cells in Phase 1

### Problem

Phase 1 groups VPC cells by `env/region` and deploys cells within each group sequentially. This was originally needed because the first cell in each group created the SSH keypair inline, and subsequent cells depended on it existing. Now that keypairs are created in Phase 0 from standalone directories, this sequential constraint is unnecessary.

### Current behaviour

```
envs/dev/euw2  → cell1000 (start) → cell1001 (waits for cell1000)  ← background job
envs/prod/euw2 → cell0000 (start) → cell0001 (waits for cell0000) ← background job
```

Groups run in parallel, but cells within a group are sequential.

### Desired behaviour

All cells run as independent parallel background jobs:

```
cell1000 (start) ← background job
cell1001 (start) ← background job
cell0000 (start) ← background job
cell0001 (start) ← background job
```

### Change in `scripts/deploy.sh`

Replace the cell grouping logic:

```bash
# Group cells by env/region key (e.g. envs/dev/euw2)
declare -A CELL_GROUPS=()
local cell group_key
for cell in "${VPC_CELLS[@]}"; do
  group_key="$(echo "$cell" | cut -d/ -f1-3)"
  CELL_GROUPS["$group_key"]+="$cell "
done

# Each group runs as a single background job; cells within the group are sequential
for group_key in "${!CELL_GROUPS[@]}"; do
  (
    for cell in $(echo "${CELL_GROUPS[$group_key]}" | tr ' ' '\n' | sort); do
      run_terraform "$cell"
    done
  ) &
  JOB_MAP[$!]="$group_key"
done
```

With fully parallel deployment:

```bash
# All VPC cells deploy in parallel — keypairs are already created in Phase 0
local cell
for cell in "${VPC_CELLS[@]}"; do
  run_terraform "$cell" &
  JOB_MAP[$!]="$cell"
done
```

Also update the Phase 1 log message from:
`"Phase 1 — VPCs + TGWs (cells sequential within env/region)"` → `"Phase 1 — VPCs + TGWs (all parallel)"`

---

## Architecture

```
envs/dev/euw2/keypair/           ( 1 — new)
  backend.tf                     # S3 key: env-dev/euw2/keypair/terraform.tfstate
  locals.tf                      # region=eu-west-2, environment=dev
  providers.tf                   # AWS + TLS + local + null providers
  keypair.tf                     # create-key-pair module call
  outputs.tf                     # key_pair_name, key_pair_path

envs/prod/euw2/keypair/          ( 2 — new)
  backend.tf                     # S3 key: env-prod/euw2/keypair/terraform.tfstate
  locals.tf                      # region=eu-west-2, environment=prod
  providers.tf                   # AWS + TLS + local + null providers
  keypair.tf                     # create-key-pair module call
  outputs.tf                     # key_pair_name, key_pair_path

envs/dev/euw1/keypair/backend.tf   ( 3 — fix region)
envs/prod/euw1/keypair/backend.tf  ( 3 — fix region)
```

---

## Validation

All s run after creating/editing files:

```bash
terraform fmt --recursive envs/dev/euw2/keypair/
terraform fmt --recursive envs/prod/euw2/keypair/
terraform fmt --recursive envs/dev/euw1/keypair/
terraform fmt --recursive envs/prod/euw1/keypair/
terraform validate  # in each directory
tflint --recursive --config=tools/.tflint.hcl
```

---

## Files Changed

|  | File | Action |
|-------|------|--------|
|  1 | `envs/dev/euw2/keypair/backend.tf` | Create |
|  1 | `envs/dev/euw2/keypair/locals.tf` | Create |
|  1 | `envs/dev/euw2/keypair/providers.tf` | Create |
|  1 | `envs/dev/euw2/keypair/keypair.tf` | Create |
|  1 | `envs/dev/euw2/keypair/outputs.tf` | Create |
|  2 | `envs/prod/euw2/keypair/backend.tf` | Create |
|  2 | `envs/prod/euw2/keypair/locals.tf` | Create |
|  2 | `envs/prod/euw2/keypair/providers.tf` | Create |
|  2 | `envs/prod/euw2/keypair/keypair.tf` | Create |
|  2 | `envs/prod/euw2/keypair/outputs.tf` | Create |
|  3 | `envs/dev/euw1/keypair/backend.tf` | Edit (region eu-west-1 → eu-west-2) |
|  3 | `envs/prod/euw1/keypair/backend.tf` | Edit (region eu-west-1 → eu-west-2) |
|  4 | `envs/dev/euw2/cell1000/keypair.tf` | Create (data source) |
|  4 | `envs/dev/euw2/cell1000/ec2s.tf` | Edit (module → data source ref) |
|  4 | `envs/dev/euw2/cell1000/outputs.tf` | Edit (ssh_key_path computed) |
|  4 | `envs/prod/euw2/cell0000/keypair.tf` | Edit (module → data source) |
|  4 | `envs/prod/euw2/cell0000/ec2s.tf` | Edit (module → data source ref) |
|  4 | `envs/prod/euw2/cell0000/outputs.tf` | Edit (ssh_key_path computed) |
|  5 | `scripts/deploy.sh` | Edit (Phase 1 fully parallel cells) |

---

## Implementation Status

| Item | Status |
|------|--------|
| `envs/dev/euw2/keypair/` — all files created | Done |
| `envs/prod/euw2/keypair/` — all files created | Done |
| `envs/dev/euw1/keypair/backend.tf` — region fixed | Done |
| `envs/prod/euw1/keypair/backend.tf` — region fixed | Done |
| Inline `module "key_pair"` removed from cell1000 and cell0000 | Done |
| `scripts/deploy.sh` — Phase 1 fully parallel cells | Pending |
| All directories pass `terraform validate` | Pending — user to test |
| All directories pass `tflint` | Pending — user to test |
| `terraform apply` — all keypair environments | Pending — user to deploy |
