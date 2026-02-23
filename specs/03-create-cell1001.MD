# Spec 03 - Create dev/euw2/cell1001

## Overview

Create the second dev cell in eu-west-2 (`cell1001`), mirroring `cell1000` with the next `/20` CIDR block (`10.1.16.0/20`), and register it in the TGW VPC attachments so that it is automatically attached to the Transit Gateway and given VPC-side routes to the TGW supernet (`10.0.0.0/8`).

Two agents work in parallel: one creates the cell environment, the other updates the TGW attachment config.

**Status**: Complete. All changes applied to AWS. cell1001 is deployed and communicating with cell1000 via TGW.

---

## Goals

1. Create all Terraform files for `envs/dev/euw2/cell1001/` mirroring `cell1000` with adjusted CIDR and cell name.
2. Register `cell1001` in `envs/networking/euw2/tgw-vpc-atts/locals.tf` so the dynamic `for_each` picks it up automatically.
3. After deployment, cell1001's private subnet route tables will have a `10.0.0.0/8 -> TGW` route, enabling east-west traffic with cell1000 and other cells.

---

## CIDR Allocation

| Resource | CIDR |
|----------|------|
| VPC | `10.1.16.0/20` |
| Private subnet priv-0 (euw2a) | `10.1.16.0/24` |
| Private subnet priv-1 (euw2b) | `10.1.17.0/24` |
| Private subnet priv-2 (euw2c) | `10.1.18.0/24` |
| Public subnet pub-0 (euw2a) | `10.1.26.0/24` |
| Public subnet pub-1 (euw2b) | `10.1.27.0/24` |
| Public subnet pub-2 (euw2c) | `10.1.28.0/24` |

S3 state key: `env-dev/euw2/cell1001/terraform.tfstate`

---

## Agent 1 — Create `envs/dev/euw2/cell1001/`

Creates the full VPC cell environment. All files mirror `cell1000` with the following differences.

### `backend.tf`

```hcl
terraform {
  backend "s3" {
    region       = "eu-west-2"
    bucket       = "dmac-bootstrap-tfstate"
    key          = "env-dev/euw2/cell1001/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
```

### `locals.tf`

Same as `cell1000` with:
- `cell_name = "cell1001"`
- Private subnet CIDRs updated to `10.1.16.x`

### `vpc.tf`

Same module call as `cell1000` with:
- `vpc_cidr = "10.1.16.0/20"`
- Private subnets: `10.1.16.0/24`, `10.1.17.0/24`, `10.1.18.0/24`
- Public subnets: `10.1.26.0/24`, `10.1.27.0/24`, `10.1.28.0/24`

### `providers.tf`, `keypair.tf`, `security.tf`, `sec-groups.tf`, `ec2s.tf`, `outputs.tf`

Identical copies from `cell1000`. All local references are already dynamic and require no changes.

**Validation (Agent 1 runs after creating files):**

```bash
terraform fmt --recursive envs/dev/euw2/cell1001/
terraform validate
tflint --recursive --config=tools/.tflint.hcl
```

---

## Agent 2 — Register cell1001 in TGW VPC Attachments

Runs in parallel with Agent 1. Updates one file only.

### `envs/networking/euw2/tgw-vpc-atts/locals.tf`

Add `cell1001` to the `dev` block of `cell_mappings`:

```hcl
dev = {
  cell1000 = {
    state_key = "env-dev/euw2/cell1000/terraform.tfstate"
  }
  cell1001 = {
    state_key = "env-dev/euw2/cell1001/terraform.tfstate"
  }
}
```

No other files need changing. The existing `for_each` in `data.tf` and `vpc-attachments.tf` automatically handles the new cell.

**Validation (Agent 2 runs after editing):**

```bash
terraform fmt --recursive envs/networking/euw2/tgw-vpc-atts/
terraform validate
tflint --recursive --config=tools/.tflint.hcl
```

---

## Architecture

```
envs/dev/euw2/cell1001/      (Agent 1 — new cell)
  backend.tf                 # S3 key: env-dev/euw2/cell1001/terraform.tfstate
  locals.tf                  # cell_name=cell1001, private subnets 10.1.16.x
  providers.tf               # unchanged from cell1000
  vpc.tf                     # vpc_cidr=10.1.16.0/20, updated subnets
  keypair.tf                 # unchanged from cell1000
  security.tf                # unchanged from cell1000
  sec-groups.tf              # unchanged from cell1000
  ec2s.tf                    # unchanged from cell1000
  outputs.tf                 # unchanged from cell1000

envs/networking/euw2/tgw-vpc-atts/locals.tf   (Agent 2 — one-line addition)
  cell_mappings.dev.cell1001 = { state_key = "env-dev/euw2/cell1001/terraform.tfstate" }
```

---

## Deployment Order (Sequential, after both agents finish)

1. `terraform apply -var-file=variables.tfvars` in `envs/dev/euw2/cell1001/`
   — Creates VPC, subnets, route tables, NAT GW, EC2, key pair, security groups.

2. `terraform apply -var target_environment=dev` in `envs/networking/euw2/tgw-vpc-atts/`
   — Creates TGW VPC attachment for cell1001 and adds `10.0.0.0/8 -> TGW` routes to its three private subnet route tables.

---

## Files Changed

| Agent | File | Action |
|-------|------|--------|
| Agent 1 | `envs/dev/euw2/cell1001/backend.tf` | Create |
| Agent 1 | `envs/dev/euw2/cell1001/locals.tf` | Create |
| Agent 1 | `envs/dev/euw2/cell1001/providers.tf` | Create (copy from cell1000) |
| Agent 1 | `envs/dev/euw2/cell1001/vpc.tf` | Create (vpc_cidr=10.1.16.0/20) |
| Agent 1 | `envs/dev/euw2/cell1001/keypair.tf` | Create (copy from cell1000) |
| Agent 1 | `envs/dev/euw2/cell1001/security.tf` | Create (copy from cell1000) |
| Agent 1 | `envs/dev/euw2/cell1001/sec-groups.tf` | Create (copy from cell1000) |
| Agent 1 | `envs/dev/euw2/cell1001/ec2s.tf` | Create (copy from cell1000) |
| Agent 1 | `envs/dev/euw2/cell1001/outputs.tf` | Create (copy from cell1000) |
| Agent 2 | `envs/networking/euw2/tgw-vpc-atts/locals.tf` | Edit (add cell1001 to dev cell_mappings) |

---

## Implementation Status

| Item | Status |
|------|--------|
| `envs/dev/euw2/cell1001/` — all files created | Complete |
| `envs/networking/euw2/tgw-vpc-atts/locals.tf` — cell1001 registered | Complete |
| All modules pass `terraform validate` | Complete |
| All modules pass `tflint` | Complete |
| `terraform apply` — cell1001 VPC deployed to AWS | Complete |
| `terraform apply` — TGW attachment + VPC-side routes applied | Complete |
| Test inter-VPC connectivity (cell1000 <-> cell1001 via TGW) | Complete |
