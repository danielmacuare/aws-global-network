# Spec 04 - Deploy prod/euw2/cell0000 and prod/euw2/cell0001

## Overview

Deploy the first two production cells in eu-west-2 per the [DESIGN.md](./DESIGN.md) IP allocation:

- `envs/prod/euw2/cell0000/` — `vpc-euw2-prod-cell0000`, VPC `10.0.0.0/20`
- `envs/prod/euw2/cell0001/` — `vpc-euw2-prod-cell0001`, VPC `10.0.16.0/20`

The TGW attachment locals (`envs/networking/euw2/tgw-vpc-atts/locals.tf`) currently have the prod block referencing `cell1000` — this must be corrected to `cell0000` to match DESIGN.md and the actual state key path.

Two agents work in parallel to create each cell. A third step corrects the TGW locals and applies the prod attachments.

**Status**: Complete — both prod cells deployed to AWS; inter-VPC routing between cell0000 and cell0001 via TGW is working

---

## Goals

1. Create `envs/prod/euw2/cell0000/` — all Terraform files, mirroring `dev/euw2/cell1000` with prod CIDRs and environment label.
2. Create `envs/prod/euw2/cell0001/` — all Terraform files, mirroring `dev/euw2/cell1001` with prod CIDRs and environment label.
3. Fix `envs/networking/euw2/tgw-vpc-atts/locals.tf` — rename `cell1000` → `cell0000` in the prod block and update the state key path.
4. Run `terraform apply -var target_environment=prod` in `envs/networking/euw2/tgw-vpc-atts/` to attach both prod VPCs to the TGW and add `10.0.0.0/8 → TGW` routes to their private subnet route tables.

---

## CIDR Allocation

All CIDRs are defined in [DESIGN.md](./DESIGN.md). Prod/euw2 uses the `10.0.0.0/16` block.

### prod/euw2/cell0000

| Resource | CIDR |
|----------|------|
| VPC | `10.0.0.0/20` |
| Private subnet priv-0 (euw2a) | `10.0.0.0/24` |
| Private subnet priv-1 (euw2b) | `10.0.1.0/24` |
| Private subnet priv-2 (euw2c) | `10.0.2.0/24` |
| Public subnet pub-0 (euw2a) | `10.0.10.0/24` |
| Public subnet pub-1 (euw2b) | `10.0.11.0/24` |
| Public subnet pub-2 (euw2c) | `10.0.12.0/24` |

S3 state key: `env-prod/euw2/cell0000/terraform.tfstate`

### prod/euw2/cell0001

| Resource | CIDR |
|----------|------|
| VPC | `10.0.16.0/20` |
| Private subnet priv-0 (euw2a) | `10.0.16.0/24` |
| Private subnet priv-1 (euw2b) | `10.0.17.0/24` |
| Private subnet priv-2 (euw2c) | `10.0.18.0/24` |
| Public subnet pub-0 (euw2a) | `10.0.26.0/24` |
| Public subnet pub-1 (euw2b) | `10.0.27.0/24` |
| Public subnet pub-2 (euw2c) | `10.0.28.0/24` |

S3 state key: `env-prod/euw2/cell0001/terraform.tfstate`

---

## Agent 1 — Create `envs/prod/euw2/cell0000/`

Mirrors `dev/euw2/cell1000` with the following differences.

### `backend.tf`

```hcl
terraform {
  backend "s3" {
    region       = "eu-west-2"
    bucket       = "dmac-bootstrap-tfstate"
    key          = "env-prod/euw2/cell0000/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
```

### `locals.tf`

Same as `dev/euw2/cell1000` with:
- `environment  = "prod"`
- `cell_name    = "cell0000"`
- Private subnet CIDRs updated to `10.0.0.x`

### `vpc.tf`

Same module call as `dev/euw2/cell1000` with:
- `vpc_cidr = "10.0.0.0/20"`
- Private subnets: `10.0.0.0/24`, `10.0.1.0/24`, `10.0.2.0/24`
- Public subnets: `10.0.10.0/24`, `10.0.11.0/24`, `10.0.12.0/24`

### `security.tf`

Same module call as `dev/euw2/cell1000` with:
- `env_supernet_cidr = "10.0.0.0/16"` (prod/euw2 supernet for cross-cell SG/NACL rules)

### `providers.tf`, `keypair.tf`, `sec-groups.tf`, `ec2s.tf`, `outputs.tf`

Identical copies from `dev/euw2/cell1000`. All local references are already dynamic.

**Validation (Agent 1 runs after creating files):**

```bash
terraform fmt --recursive envs/prod/euw2/cell0000/
terraform validate
tflint --recursive --config=tools/.tflint.hcl
```

---

## Agent 2 — Create `envs/prod/euw2/cell0001/`

Mirrors `dev/euw2/cell1001` with the following differences.

### `backend.tf`

```hcl
terraform {
  backend "s3" {
    region       = "eu-west-2"
    bucket       = "dmac-bootstrap-tfstate"
    key          = "env-prod/euw2/cell0001/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
```

### `locals.tf`

Same as `dev/euw2/cell1001` with:
- `environment  = "prod"`
- `cell_name    = "cell0001"`
- Private subnet CIDRs updated to `10.0.16.x`

### `vpc.tf`

Same module call as `dev/euw2/cell1001` with:
- `vpc_cidr = "10.0.16.0/20"`
- Private subnets: `10.0.16.0/24`, `10.0.17.0/24`, `10.0.18.0/24`
- Public subnets: `10.0.26.0/24`, `10.0.27.0/24`, `10.0.28.0/24`

### `security.tf`

Same module call as `dev/euw2/cell1001` with:
- `env_supernet_cidr = "10.0.0.0/16"` (prod/euw2 supernet for cross-cell SG/NACL rules)

### `providers.tf`, `keypair.tf`, `sec-groups.tf`, `ec2s.tf`, `outputs.tf`

Identical copies from `dev/euw2/cell1001`. All local references are already dynamic.

**Validation (Agent 2 runs after creating files):**

```bash
terraform fmt --recursive envs/prod/euw2/cell0001/
terraform validate
tflint --recursive --config=tools/.tflint.hcl
```

---

## Agent 3 — Fix TGW locals and apply prod attachments

Runs after both agents finish.

### `envs/networking/euw2/tgw-vpc-atts/locals.tf`

The prod block currently has an incorrect `cell1000` entry. Rename it to `cell0000` and update the state key:

```hcl
prod = {
  cell0000 = {
    state_key = "env-prod/euw2/cell0000/terraform.tfstate"
  }
  cell0001 = {
    state_key = "env-prod/euw2/cell0001/terraform.tfstate"
  }
}
```

**Validation:**

```bash
terraform fmt --recursive envs/networking/euw2/tgw-vpc-atts/
terraform validate
tflint --recursive --config=tools/.tflint.hcl
```

---

## Architecture

```
envs/prod/euw2/cell0000/        (Agent 1 — new prod cell)
  backend.tf                    # S3 key: env-prod/euw2/cell0000/terraform.tfstate
  locals.tf                     # environment=prod, cell_name=cell0000, private 10.0.0.x
  providers.tf                  # copy from dev/cell1000
  vpc.tf                        # vpc_cidr=10.0.0.0/20, updated subnets
  keypair.tf                    # copy from dev/cell1000
  security.tf                   # env_supernet_cidr=10.0.0.0/16
  sec-groups.tf                 # copy from dev/cell1000
  ec2s.tf                       # copy from dev/cell1000
  outputs.tf                    # copy from dev/cell1000

envs/prod/euw2/cell0001/        (Agent 2 — new prod cell)
  backend.tf                    # S3 key: env-prod/euw2/cell0001/terraform.tfstate
  locals.tf                     # environment=prod, cell_name=cell0001, private 10.0.16.x
  providers.tf                  # copy from dev/cell1001
  vpc.tf                        # vpc_cidr=10.0.16.0/20, updated subnets
  keypair.tf                    # copy from dev/cell1001
  security.tf                   # env_supernet_cidr=10.0.0.0/16
  sec-groups.tf                 # copy from dev/cell1001
  ec2s.tf                       # copy from dev/cell1001
  outputs.tf                    # copy from dev/cell1001

envs/networking/euw2/tgw-vpc-atts/locals.tf  (Agent 3 — fix cell1000 → cell0000 in prod block)
```

---

## Deployment Order

### Step 1 — Deploy cells in parallel (Agent 1 and Agent 2, after code is written)

Both cells are independent. Agents 1 and 2 each run their own apply concurrently:

- Agent 1: `terraform apply -var-file=variables.tfvars` in `envs/prod/euw2/cell0000/`
  — Creates VPC, subnets, route tables, NAT GW, EC2, key pair, security groups.

- Agent 2: `terraform apply -var-file=variables.tfvars` in `envs/prod/euw2/cell0001/`
  — Same as above for the second prod cell.

### Step 2 — Attach to TGW (Agent 3, after both cells are deployed)

`terraform apply -var target_environment=prod` in `envs/networking/euw2/tgw-vpc-atts/`
— Creates TGW VPC attachments for both prod cells and adds `10.0.0.0/8 → TGW` routes to their private subnet route tables.

---

## Files Changed

| Agent | File | Action |
|-------|------|--------|
| Agent 1 | `envs/prod/euw2/cell0000/backend.tf` | Create |
| Agent 1 | `envs/prod/euw2/cell0000/locals.tf` | Create |
| Agent 1 | `envs/prod/euw2/cell0000/providers.tf` | Create (copy from dev/cell1000) |
| Agent 1 | `envs/prod/euw2/cell0000/vpc.tf` | Create (vpc_cidr=10.0.0.0/20) |
| Agent 1 | `envs/prod/euw2/cell0000/keypair.tf` | Create (copy from dev/cell1000) |
| Agent 1 | `envs/prod/euw2/cell0000/security.tf` | Create (env_supernet_cidr=10.0.0.0/16) |
| Agent 1 | `envs/prod/euw2/cell0000/sec-groups.tf` | Create (copy from dev/cell1000) |
| Agent 1 | `envs/prod/euw2/cell0000/ec2s.tf` | Create (copy from dev/cell1000) |
| Agent 1 | `envs/prod/euw2/cell0000/outputs.tf` | Create (copy from dev/cell1000) |
| Agent 2 | `envs/prod/euw2/cell0001/backend.tf` | Create |
| Agent 2 | `envs/prod/euw2/cell0001/locals.tf` | Create |
| Agent 2 | `envs/prod/euw2/cell0001/providers.tf` | Create (copy from dev/cell1001) |
| Agent 2 | `envs/prod/euw2/cell0001/vpc.tf` | Create (vpc_cidr=10.0.16.0/20) |
| Agent 2 | `envs/prod/euw2/cell0001/keypair.tf` | Create (copy from dev/cell1001) |
| Agent 2 | `envs/prod/euw2/cell0001/security.tf` | Create (env_supernet_cidr=10.0.0.0/16) |
| Agent 2 | `envs/prod/euw2/cell0001/sec-groups.tf` | Create (copy from dev/cell1001) |
| Agent 2 | `envs/prod/euw2/cell0001/ec2s.tf` | Create (copy from dev/cell1001) |
| Agent 2 | `envs/prod/euw2/cell0001/outputs.tf` | Create (copy from dev/cell1001) |
| Agent 3 | `envs/networking/euw2/tgw-vpc-atts/locals.tf` | Edit (rename cell1000 → cell0000 in prod block, update state key) |

---

## Implementation Status

| Item | Status |
|------|--------|
| `envs/prod/euw2/cell0000/` — all files created | Pending |
| `envs/prod/euw2/cell0001/` — all files created | Pending |
| `envs/networking/euw2/tgw-vpc-atts/locals.tf` — cell1000 → cell0000 in prod block | Pending |
| All modules pass `terraform validate` | Pending |
| All modules pass `tflint` | Pending |
| `terraform apply` — cell0000 prod VPC deployed to AWS | Complete |
| `terraform apply` — cell0001 prod VPC deployed to AWS | Complete |
| `terraform apply -var target_environment=prod` — TGW attachments + VPC-side routes applied | Complete |
| Test inter-VPC connectivity (cell0000 <-> cell0001 via TGW in prod) | Pending |
