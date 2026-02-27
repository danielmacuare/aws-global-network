# Spec 08 — Deploy Regions us-west-2 and us-west-1

**Status**: Not started

## Overview

Deploy a full us-west-2 (Oregon) and us-west-1 (N. California) regional stack to mirror what is currently running in eu-west-2 and eu-west-1. This includes:

- Transit Gateways for each new region
- 4 dev cells and 4 prod cells across the two new regions
- TGW-VPC attachments for all cells
- Key pair deployments (dev + prod, both regions)
- Full-mesh TGW peering across all four regions (6 total attachments)

After deployment, validate end-to-end cross-region connectivity and environment isolation.

---

## IP Allocation

Per `specs/DESIGN.md`:

| VPC Name | Environment | VPC CIDR | Region |
|---|---|---|---|
| vpc-usw2-prod-cell4000 | prod | 10.32.0.0/20 | us-west-2 |
| vpc-usw2-prod-cell4001 | prod | 10.32.16.0/20 | us-west-2 |
| vpc-usw2-dev-cell5000 | dev | 10.33.0.0/20 | us-west-2 |
| vpc-usw2-dev-cell5001 | dev | 10.33.16.0/20 | us-west-2 |
| vpc-usw1-prod-cell6000 | prod | 10.48.0.0/20 | us-west-1 |
| vpc-usw1-prod-cell6001 | prod | 10.48.16.0/20 | us-west-1 |
| vpc-usw1-dev-cell7000 | dev | 10.49.0.0/20 | us-west-1 |
| vpc-usw1-dev-cell7001 | dev | 10.49.16.0/20 | us-west-1 |

### Environment Supernets (for Security Groups and NACLs)

| Region | Environment | env_supernet_cidr |
|---|---|---|
| usw2 | prod | 10.32.0.0/16 |
| usw2 | dev | 10.33.0.0/16 |
| usw1 | prod | 10.48.0.0/16 |
| usw1 | dev | 10.49.0.0/16 |

### TGW ASNs

| Region | ASN |
|---|---|
| euw2 | 64514 (existing) |
| euw1 | 64515 (existing) |
| usw1 | 64517 (new) |
| usw2 | 64518 (new) |

---

## State File Locations

All state stored in S3 bucket `dmac-bootstrap-tfstate`, backend region `eu-west-2`.

| Directory | State Key |
|---|---|
| `envs/dev/usw2/keypair/` | `env-dev/usw2/keypair/terraform.tfstate` |
| `envs/prod/usw2/keypair/` | `env-prod/usw2/keypair/terraform.tfstate` |
| `envs/dev/usw1/keypair/` | `env-dev/usw1/keypair/terraform.tfstate` |
| `envs/prod/usw1/keypair/` | `env-prod/usw1/keypair/terraform.tfstate` |
| `envs/networking/usw2/tgw/` | `env-networking/usw2-tgw/terraform.tfstate` |
| `envs/networking/usw1/tgw/` | `env-networking/usw1-tgw/terraform.tfstate` |
| `envs/prod/usw2/cell4000/` | `env-prod/usw2/cell4000/terraform.tfstate` |
| `envs/prod/usw2/cell4001/` | `env-prod/usw2/cell4001/terraform.tfstate` |
| `envs/dev/usw2/cell5000/` | `env-dev/usw2/cell5000/terraform.tfstate` |
| `envs/dev/usw2/cell5001/` | `env-dev/usw2/cell5001/terraform.tfstate` |
| `envs/prod/usw1/cell6000/` | `env-prod/usw1/cell6000/terraform.tfstate` |
| `envs/prod/usw1/cell6001/` | `env-prod/usw1/cell6001/terraform.tfstate` |
| `envs/dev/usw1/cell7000/` | `env-dev/usw1/cell7000/terraform.tfstate` |
| `envs/dev/usw1/cell7001/` | `env-dev/usw1/cell7001/terraform.tfstate` |
| `envs/networking/usw2/tgw-vpc-atts/` | `env-networking/usw2-tgw-vpc-atts/terraform.tfstate` |
| `envs/networking/usw1/tgw-vpc-atts/` | `env-networking/usw1-tgw-vpc-atts/terraform.tfstate` |
| `envs/networking/global/tgw-peering/` | `env-networking/global-tgw-peering/terraform.tfstate` (existing, updated in-place) |

---

## TGW Peering Mesh

Full-mesh topology across all four regions (6 total attachments):

| Attachment Name | Requester | Accepter | New in Spec 08? |
|---|---|---|---|
| `tgw-att-euw2-euw1-pcx` | euw2 | euw1 | No (existing) |
| `tgw-att-euw2-usw2-pcx` | euw2 | usw2 | Yes |
| `tgw-att-euw2-usw1-pcx` | euw2 | usw1 | Yes |
| `tgw-att-euw1-usw2-pcx` | euw1 | usw2 | Yes |
| `tgw-att-euw1-usw1-pcx` | euw1 | usw1 | Yes |
| `tgw-att-usw2-usw1-pcx` | usw2 | usw1 | Yes |

Full mesh is required so that all regions can route directly to each other without hairpinning through a hub. Each region's prod and dev route tables carry one static /16 route per remote region via the appropriate peering attachment.

---

## Prerequisite — Security Module Update

The existing `modules/security` module accepts a single `cross_region_supernet_cidr` string. usw2 and usw1 cells peer with three other regions each, so the module must be extended to accept a list.

**`modules/security/variables.tf`** — add:

```hcl
variable "cross_region_supernet_cidrs" {
  type        = list(string)
  description = "List of peer-region environment supernet CIDRs for cross-region TGW peering traffic."
  default     = []
}
```

**`modules/security/security-groups.tf`** — add a second dynamic ingress block iterating over the list (the existing string-based block is preserved for backward compatibility):

```hcl
dynamic "ingress" {
  for_each = var.cross_region_supernet_cidrs
  content {
    description = "All traffic from peer-region cells via TGW peering"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ingress.value]
  }
}
```

**`modules/security/nacls.tf`** — add dynamic NACL rules starting at rule number 130 (one per CIDR in the list). Existing euw1/euw2 cells continue using the string variable unchanged.

---

## Phase-by-Phase Deployment

### Phase 0 — Key Pairs (parallel)

Deploy in parallel:
- `envs/dev/usw2/keypair/`
- `envs/prod/usw2/keypair/`
- `envs/dev/usw1/keypair/`
- `envs/prod/usw1/keypair/`

The `deploy.py` `discover_keypairs()` function picks these up automatically once the directories exist.

### Phase 1 — TGWs and VPC Cells (parallel)

All can deploy simultaneously (no inter-dependencies):
- `envs/networking/usw2/tgw/`
- `envs/networking/usw1/tgw/`
- `envs/prod/usw2/cell4000/`, `cell4001/`
- `envs/dev/usw2/cell5000/`, `cell5001/`
- `envs/prod/usw1/cell6000/`, `cell6001/`
- `envs/dev/usw1/cell7000/`, `cell7001/`

Wait 30 seconds after Phase 1 (consistent with existing deploy.py timing gate).

### Phase 2 — TGW-VPC Attachments (parallel)

- `envs/networking/usw2/tgw-vpc-atts/`
- `envs/networking/usw1/tgw-vpc-atts/`

### Phase 3 — TGW Peering (sequential, single apply)

Update `envs/networking/global/tgw-peering/` in-place. A single `terraform apply` adds the 5 new peering attachments without affecting the existing euw2↔euw1 attachment. The TGW peering readiness gate in `peering_gate.py` will automatically verify usw2 and usw1 TGWs once their `terraform_remote_state` blocks are added to `data.tf`.

---

## Terraform HCL — Key Configurations

### Key Pairs

All four keypair directories mirror `envs/dev/euw1/keypair/`. Only `locals.tf` and `backend.tf` differ.

**`envs/dev/usw2/keypair/locals.tf`**

```hcl
locals {
  region       = "us-west-2"
  region_short = "usw2"
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

Variants: `prod/usw2` → `environment = "prod"`, `dev/usw1` → `region = "us-west-1"`, `region_short = "usw1"`, `prod/usw1` → both.

### TGWs

Mirror `envs/networking/euw1/tgw/` substituting region values.

**`envs/networking/usw2/tgw/locals.tf`**

```hcl
locals {
  region          = "us-west-2"
  region_short    = "usw2"
  amazon_side_asn = 64518
  default_tags = { ... }
}
```

**`envs/networking/usw1/tgw/locals.tf`**: `region = "us-west-1"`, `region_short = "usw1"`, `amazon_side_asn = 64517`.

`tgw.tf` and `outputs.tf` are identical to `envs/networking/euw1/tgw/` — no hardcoded values.

### VPC Cells — usw2

| cell_name | env | vpc_cidr | priv-0 | priv-1 | priv-2 | pub-0 | pub-1 | pub-2 |
|---|---|---|---|---|---|---|---|---|
| cell4000 | prod | 10.32.0.0/20 | 10.32.0.0/24 | 10.32.1.0/24 | 10.32.2.0/24 | 10.32.10.0/24 | 10.32.11.0/24 | 10.32.12.0/24 |
| cell4001 | prod | 10.32.16.0/20 | 10.32.16.0/24 | 10.32.17.0/24 | 10.32.18.0/24 | 10.32.26.0/24 | 10.32.27.0/24 | 10.32.28.0/24 |
| cell5000 | dev | 10.33.0.0/20 | 10.33.0.0/24 | 10.33.1.0/24 | 10.33.2.0/24 | 10.33.10.0/24 | 10.33.11.0/24 | 10.33.12.0/24 |
| cell5001 | dev | 10.33.16.0/20 | 10.33.16.0/24 | 10.33.17.0/24 | 10.33.18.0/24 | 10.33.26.0/24 | 10.33.27.0/24 | 10.33.28.0/24 |

AZs: `us-west-2a`, `us-west-2b`, `us-west-2c`.

**`security.tf` for usw2-prod cells** (e.g. cell4000):

```hcl
module "security" {
  source       = "../../../../modules/security"
  ...
  env_supernet_cidr           = "10.32.0.0/16"
  cross_region_supernet_cidrs = [
    "10.0.0.0/16",   # euw2-prod
    "10.16.0.0/16",  # euw1-prod
    "10.48.0.0/16",  # usw1-prod
  ]
}
```

**`security.tf` for usw2-dev cells** (e.g. cell5000):

```hcl
  env_supernet_cidr           = "10.33.0.0/16"
  cross_region_supernet_cidrs = [
    "10.1.0.0/16",   # euw2-dev
    "10.17.0.0/16",  # euw1-dev
    "10.49.0.0/16",  # usw1-dev
  ]
```

### VPC Cells — usw1

| cell_name | env | vpc_cidr | priv-0 | priv-1 | pub-0 | pub-1 |
|---|---|---|---|---|---|---|
| cell6000 | prod | 10.48.0.0/20 | 10.48.0.0/24 | 10.48.1.0/24 | 10.48.10.0/24 | 10.48.11.0/24 |
| cell6001 | prod | 10.48.16.0/20 | 10.48.16.0/24 | 10.48.17.0/24 | 10.48.26.0/24 | 10.48.27.0/24 |
| cell7000 | dev | 10.49.0.0/20 | 10.49.0.0/24 | 10.49.1.0/24 | 10.49.10.0/24 | 10.49.11.0/24 |
| cell7001 | dev | 10.49.16.0/20 | 10.49.16.0/24 | 10.49.17.0/24 | 10.49.26.0/24 | 10.49.27.0/24 |

**us-west-1 AZ constraint**: Only two AZs exist — `us-west-1a` and `us-west-1b`. usw1 cells have only `priv-0` and `priv-1` (no `priv-2`/`pub-2`). The `create-vpc` module uses `for_each` on the subnets map, so variable counts are supported without code changes.

**`security.tf` for usw1-prod cells**:

```hcl
  env_supernet_cidr           = "10.48.0.0/16"
  cross_region_supernet_cidrs = [
    "10.0.0.0/16",   # euw2-prod
    "10.16.0.0/16",  # euw1-prod
    "10.32.0.0/16",  # usw2-prod
  ]
```

**`security.tf` for usw1-dev cells**:

```hcl
  env_supernet_cidr           = "10.49.0.0/16"
  cross_region_supernet_cidrs = [
    "10.1.0.0/16",   # euw2-dev
    "10.17.0.0/16",  # euw1-dev
    "10.33.0.0/16",  # usw2-dev
  ]
```

### TGW-VPC Attachments

Mirror `envs/networking/euw1/tgw-vpc-atts/`.

**`envs/networking/usw2/tgw-vpc-atts/locals.tf`**

```hcl
locals {
  region       = "us-west-2"
  region_short = "usw2"
  cell_mappings = {
    cell4000 = { state_key = "env-prod/usw2/cell4000/terraform.tfstate", environment = "prod" }
    cell4001 = { state_key = "env-prod/usw2/cell4001/terraform.tfstate", environment = "prod" }
    cell5000 = { state_key = "env-dev/usw2/cell5000/terraform.tfstate",  environment = "dev"  }
    cell5001 = { state_key = "env-dev/usw2/cell5001/terraform.tfstate",  environment = "dev"  }
  }
  tgw_supernet_cidr = "10.0.0.0/8"
  ...
}
```

**`envs/networking/usw1/tgw-vpc-atts/locals.tf`**: same pattern with cell6000/6001 (prod) and cell7000/7001 (dev).

### TGW Peering — Updated `envs/networking/global/tgw-peering/`

**`providers.tf`** — add two new provider aliases:

```hcl
provider "aws" {
  alias  = "usw2"
  region = "us-west-2"
}

provider "aws" {
  alias  = "usw1"
  region = "us-west-1"
}
```

**`data.tf`** — add two new remote state blocks:

```hcl
data "terraform_remote_state" "usw2_tgw" {
  backend = "s3"
  config = {
    region  = "eu-west-2"
    bucket  = "dmac-bootstrap-tfstate"
    key     = "env-networking/usw2-tgw/terraform.tfstate"
    encrypt = true
  }
}

data "terraform_remote_state" "usw1_tgw" {
  backend = "s3"
  config = {
    region  = "eu-west-2"
    bucket  = "dmac-bootstrap-tfstate"
    key     = "env-networking/usw1-tgw/terraform.tfstate"
    encrypt = true
  }
}
```

**`tgw-peering.tf`** — extend locals and add 5 new peering blocks (euw2↔usw2, euw2↔usw1, euw1↔usw2, euw1↔usw1, usw2↔usw1) each following the existing euw2↔euw1 pattern:

```hcl
# New CIDRs to add to locals block
usw2_prod_cidr = "10.32.0.0/16"
usw2_dev_cidr  = "10.33.0.0/16"
usw1_prod_cidr = "10.48.0.0/16"
usw1_dev_cidr  = "10.49.0.0/16"
```

Each new peering block includes: `aws_ec2_transit_gateway_peering_attachment` (requester), `aws_ec2_transit_gateway_peering_attachment_accepter` (accepter, aliased provider), `time_sleep` (120s stabilisation), two `aws_ec2_transit_gateway_route_table_association` resources (one per side on WAN route table), and four `aws_ec2_transit_gateway_route` static routes (prod+dev on each side).

---

## Complete Static Route Summary

| Region | Route Table | Destination | Via Attachment |
|---|---|---|---|
| euw2 | prod | 10.16.0.0/16 | euw2↔euw1 (existing) |
| euw2 | prod | 10.32.0.0/16 | euw2↔usw2 (new) |
| euw2 | prod | 10.48.0.0/16 | euw2↔usw1 (new) |
| euw2 | dev | 10.17.0.0/16 | euw2↔euw1 (existing) |
| euw2 | dev | 10.33.0.0/16 | euw2↔usw2 (new) |
| euw2 | dev | 10.49.0.0/16 | euw2↔usw1 (new) |
| euw1 | prod | 10.0.0.0/16 | euw2↔euw1 (existing, accepter) |
| euw1 | prod | 10.32.0.0/16 | euw1↔usw2 (new) |
| euw1 | prod | 10.48.0.0/16 | euw1↔usw1 (new) |
| euw1 | dev | 10.1.0.0/16 | euw2↔euw1 (existing, accepter) |
| euw1 | dev | 10.33.0.0/16 | euw1↔usw2 (new) |
| euw1 | dev | 10.49.0.0/16 | euw1↔usw1 (new) |
| usw2 | prod | 10.0.0.0/16 | euw2↔usw2 (accepter) |
| usw2 | prod | 10.16.0.0/16 | euw1↔usw2 (accepter) |
| usw2 | prod | 10.48.0.0/16 | usw2↔usw1 (new) |
| usw2 | dev | 10.1.0.0/16 | euw2↔usw2 (accepter) |
| usw2 | dev | 10.17.0.0/16 | euw1↔usw2 (accepter) |
| usw2 | dev | 10.49.0.0/16 | usw2↔usw1 (new) |
| usw1 | prod | 10.0.0.0/16 | euw2↔usw1 (accepter) |
| usw1 | prod | 10.16.0.0/16 | euw1↔usw1 (accepter) |
| usw1 | prod | 10.32.0.0/16 | usw2↔usw1 (accepter) |
| usw1 | dev | 10.1.0.0/16 | euw2↔usw1 (accepter) |
| usw1 | dev | 10.17.0.0/16 | euw1↔usw1 (accepter) |
| usw1 | dev | 10.33.0.0/16 | usw2↔usw1 (accepter) |

---

## Python Scripts — No Changes Required

The `deploy.py` and `destroy.py` scripts require **zero changes**. The discovery layer is fully filesystem-driven:

| Function | Picks up automatically |
|---|---|
| `discover_keypairs()` | `envs/dev/usw2/keypair/`, `envs/prod/usw2/keypair/`, `envs/dev/usw1/keypair/`, `envs/prod/usw1/keypair/` |
| `discover_tgws()` | `envs/networking/usw2/tgw/`, `envs/networking/usw1/tgw/` |
| `discover_vpc_cells()` | All eight new cell directories |
| `discover_tgw_vpc_atts()` | `envs/networking/usw2/tgw-vpc-atts/`, `envs/networking/usw1/tgw-vpc-atts/` |
| `discover_tgw_peering()` | Already returns `envs/networking/global/tgw-peering/` |

The peering gate (`peering_gate.py`) uses the regex `r'key\s*=\s*"([^"]*-tgw[^"]*)"'` which already matches `usw2-tgw` and `usw1-tgw` keys. Once the two new `terraform_remote_state` blocks are added to `data.tf`, the gate will automatically include all four regions.

---

## Unit Test Updates

### `scripts/tests/test_discovery.py`

Add `TestDiscoverUsw2Usw1` class covering:
- `discover_vpc_cells` picks up usw2 and usw1
- `discover_tgws` picks up usw2 and usw1
- `discover_keypairs` picks up usw2 and usw1
- Region filter `--regions usw2` excludes usw1, euw2, euw1

### `scripts/tests/test_peering_gate.py`

Add `SAMPLE_DATA_TF_FOUR_REGIONS` fixture (4 remote state blocks) and `TestExtractTgwDirsFourRegions` verifying:
- All four TGW dirs extracted correctly
- Gate fails when one region (e.g. usw2) TGW not yet applied

---

## CLI Examples

```bash
# Deploy both new regions
python scripts/deploy.py --regions usw2,usw1

# Deploy usw2 only, dev environment
python scripts/deploy.py --regions usw2 --environment dev

# Dry-run (no AWS changes)
python scripts/deploy.py --regions usw2,usw1 --dry-run

# Incremental: deploy TGWs+VPCs first, skip peering
python scripts/deploy.py --regions usw2,usw1 --skip-peering
# Then run full deploy once TGWs confirmed
python scripts/deploy.py --regions usw2,usw1

# Deploy all four regions
python scripts/deploy.py

# Destroy new regions (dry-run)
python scripts/destroy.py --regions usw2,usw1 --dry-run
```

---

## Validation

### Dry-run smoke test

```bash
python scripts/deploy.py --regions usw2,usw1 --dry-run
# Expected:
#   Phase 0: 4 keypair dirs (parallel)
#   Phase 1: 10 dirs — 2 TGWs + 8 VPCs (parallel)
#   Phase 2: 2 tgw-vpc-atts dirs (parallel)
#   Phase 3: peering gate checks euw2, euw1, usw2, usw1
```

### Terraform validation

```bash
terraform fmt --recursive .
for dir in \
  envs/networking/usw2/tgw \
  envs/networking/usw1/tgw \
  envs/prod/usw2/cell4000 envs/prod/usw2/cell4001 \
  envs/dev/usw2/cell5000  envs/dev/usw2/cell5001 \
  envs/prod/usw1/cell6000 envs/prod/usw1/cell6001 \
  envs/dev/usw1/cell7000  envs/dev/usw1/cell7001 \
  envs/networking/usw2/tgw-vpc-atts \
  envs/networking/usw1/tgw-vpc-atts \
  envs/networking/global/tgw-peering; do
  terraform -chdir=$dir validate
done
tflint --recursive --config=tools/.tflint.hcl
```

### Unit tests

```bash
cd scripts && uv sync
uv run pytest tests/ -v
```

### Post-deploy connectivity

1. SSH to bastion in usw2-dev (cell5000) → ping a private IP in euw2-dev (`10.1.0.x`) — cross-region, same env
2. SSH to bastion in usw1-dev (cell7000) → ping usw2-dev (`10.33.0.x`) — direct usw1↔usw2 path
3. SSH to bastion in usw1-dev (cell7000) → ping euw1-dev (`10.17.0.x`) — direct usw1↔euw1 path
4. From usw2-prod, verify **no route** to usw2-dev (`10.33.0.x`) — env isolation enforced

---

## Post-Apply Cleanup

**TGW Peering `moved` blocks.** The existing euw2↔euw1 peering resources were renamed from `.this` to `.euw2_euw1` for consistency with the 5 new peering blocks. `moved` blocks in `tgw-peering.tf` handle the state migration so Terraform won't destroy/recreate the live peering. After the first successful `terraform apply` on `envs/networking/global/tgw-peering/`, confirm the plan shows no unexpected destroys, then remove the `moved` blocks from the file — they are no longer needed once the state has been updated.

---

## Risks and Gotchas

**us-west-1 AZ count.** us-west-1 has only two AZs (`us-west-1a`, `us-west-1b`). usw1 cells must define only `priv-0` and `priv-1` (no `priv-2`/`pub-2`). The `create-vpc` module uses `for_each`, so this works without module changes.

**Security module backward compatibility.** The new `cross_region_supernet_cidrs` list variable defaults to `[]`. Existing euw1/euw2 cell `security.tf` files continue working unchanged.

**Peering attachment WAN route table associations.** Each peering attachment gets its own association with the WAN route table. With 6 total attachments, euw2's WAN table will have 3 associations — one per attachment — which is valid (the constraint is one association per attachment, not per route table).

**120-second `time_sleep` per new peering attachment.** Five new `time_sleep` resources will be created. Terraform may parallelise independent waits (e.g. euw1↔usw2 and usw2↔usw1 have no inter-dependency), reducing total apply time.

**State key convention for peering gate.** The gate regex `r"env-networking/([^/]+)-tgw/"` extracts `usw2` from `env-networking/usw2-tgw/terraform.tfstate` and constructs path `envs/networking/usw2/tgw`. Directory names must use `usw2`/`usw1` short-names consistently.

**Destroy ordering.** All 6 peering attachments live in one Terraform state (`global/tgw-peering`). A single `terraform destroy` on that directory tears all of them down correctly, which is the existing destroy.py Phase 1 behaviour.

---

## Files to Create / Modify

### Create (net new)

| Directory | Files |
|---|---|
| `envs/dev/usw2/keypair/` | `backend.tf`, `locals.tf`, `providers.tf`, `keypair.tf`, `outputs.tf` |
| `envs/prod/usw2/keypair/` | same |
| `envs/dev/usw1/keypair/` | same |
| `envs/prod/usw1/keypair/` | same |
| `envs/networking/usw2/tgw/` | `backend.tf`, `locals.tf`, `providers.tf`, `tgw.tf`, `outputs.tf` |
| `envs/networking/usw1/tgw/` | same |
| `envs/prod/usw2/cell4000/` | `backend.tf`, `locals.tf`, `providers.tf`, `keypair.tf`, `vpc.tf`, `security.tf`, `ec2s.tf`, `shared-vars.tf`, `outputs.tf` |
| `envs/prod/usw2/cell4001/` | same |
| `envs/dev/usw2/cell5000/` | same |
| `envs/dev/usw2/cell5001/` | same |
| `envs/prod/usw1/cell6000/` | same |
| `envs/prod/usw1/cell6001/` | same |
| `envs/dev/usw1/cell7000/` | same |
| `envs/dev/usw1/cell7001/` | same |
| `envs/networking/usw2/tgw-vpc-atts/` | `backend.tf`, `locals.tf`, `providers.tf`, `variables.tf`, `data.tf`, `vpc-attachments.tf`, `outputs.tf` |
| `envs/networking/usw1/tgw-vpc-atts/` | same |

### Modify (additions only)

| File | Change |
|---|---|
| `modules/security/variables.tf` | Add `cross_region_supernet_cidrs` list variable |
| `modules/security/security-groups.tf` | Add second dynamic ingress block for list |
| `modules/security/nacls.tf` | Add dynamic NACL rules starting at rule 130 |
| `envs/networking/global/tgw-peering/providers.tf` | Add `aws.usw2` and `aws.usw1` aliases |
| `envs/networking/global/tgw-peering/data.tf` | Add `usw2_tgw` and `usw1_tgw` remote state blocks |
| `envs/networking/global/tgw-peering/tgw-peering.tf` | Add 5 new peering blocks with static routes |
| `envs/networking/global/tgw-peering/outputs.tf` | Add new peering outputs |
| `scripts/tests/test_discovery.py` | Add `TestDiscoverUsw2Usw1` |
| `scripts/tests/test_peering_gate.py` | Add four-region fixture and tests |
| `specs/index.md` | Mark spec 08 as Complete when done |
