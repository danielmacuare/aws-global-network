# Transit Gateway

## Overview

The Transit Gateway (TGW) infrastructure is split into two Terraform modules:

1. **`create-tgw`** — Transit Gateway + Route Tables
2. **`create-tgw-vpc-attachment`** — VPC Attachments + Associations + Propagations

This separation reflects lifecycle independence: TGWs are long-lived infrastructure; attachments change frequently. Each module maintains its own state file to reduce blast radius and enable parallel operations.

---

## Architecture

```
Transit Gateway (tgw-euw2)
├── Route Table: rt-tgw-euw2-prod    (Production environment)
├── Route Table: rt-tgw-euw2-dev     (Development environment)
└── Route Table: rt-tgw-euw2-shared  (Shared services)
```

```
┌─────────────────────┐
│  Dev VPC (10.0.0.0) │
└──────────┬──────────┘
           │ attachment
           ▼
    ┌──────────────┐
    │rt-tgw-euw2-dev│ ◄──────┐
    └──────────────┘         │
                             │
┌─────────────────────┐      │      ┌──────────────────┐
│ Prod VPC (10.1.0.0) │      │      │  TGW (tgw-euw2)  │
└──────────┬──────────┘      │      └──────────────────┘
           │ attachment      │
           ▼                 │
    ┌──────────────┐         │
    │rt-tgw-euw2-prod│ ◄─────┤
    └──────────────┘         │
                             │
┌─────────────────────┐      │
│Shared VPC (10.2.0.0)│      │
└──────────┬──────────┘      │
           │ attachment      │
           ▼                 │
    ┌──────────────┐         │
    │rt-tgw-euw2-shared│ ◄───┘
    └──────────────┘
```

VPCs attached to different route tables cannot communicate by default.

---

## Module Structure

```
modules/create-tgw/
├── providers.tf      # Terraform and provider version constraints
├── variables.tf      # Input variables
├── locals.tf         # Local value computations
├── tgw.tf            # Transit Gateway resource
├── route-tables.tf   # Route table resources
└── outputs.tf        # Module outputs
```

---

## Input Variables

### Required

| Variable | Type | Description |
|----------|------|-------------|
| `default_tags` | map(string) | Standard project tags |
| `region` | string | Full AWS region name (e.g., `eu-west-2`) |
| `region_short` | string | Short region code (e.g., `euw2`) |
| `amazon_side_asn` | number | BGP ASN for the Transit Gateway |

### Optional

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `dns_support` | string | `"enable"` | Enable DNS support |
| `vpn_ecmp_support` | string | `"disable"` | Enable VPN ECMP support |
| `default_route_table_association` | string | `"disable"` | Enable default route table association |
| `default_route_table_propagation` | string | `"disable"` | Enable default route table propagation |
| `multicast_support` | string | `"disable"` | Enable multicast support |

## Outputs

| Output | Description |
|--------|-------------|
| `transit_gateway` | Full Transit Gateway resource object |
| `route_table_prod` | Production route table resource object |
| `route_table_dev` | Development route table resource object |
| `route_table_shared` | Shared services route table resource object |

Full object exports allow downstream consumers to access any attribute without module updates.

---

## Usage Example

```hcl
module "tgw" {
  source = "../../../modules/create-tgw"

  region          = "eu-west-2"
  region_short    = "euw2"
  amazon_side_asn = 64514

  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment          = "networking-tgw"
    region               = "eu-west-2"
    region_short         = "euw2"
  }
}
```

---

## Naming Conventions

| Resource | Pattern | Example |
|----------|---------|---------|
| Transit Gateway | `tgw-{region_short}` | `tgw-euw2` |
| Route Tables | `rt-tgw-{region_short}-{environment}` | `rt-tgw-euw2-dev` |
| VPC Attachments | `tgw-att-{region_short}-{environment}-{vpc_name}` | `tgw-att-euw2-dev-main` |

---

## Route Table Strategy

Three route tables are created per region from day one, even if not immediately used:

- **`rt-tgw-{region_short}-prod`** — Production VPCs only; strictly isolated from dev
- **`rt-tgw-{region_short}-dev`** — Development VPCs only
- **`rt-tgw-{region_short}-shared`** — Shared services; can be configured to reach prod and/or dev

**Why three from the start**: Adding route tables later with existing attachments requires migration. Creating them upfront avoids that.

### Disabled Default Association/Propagation

`default_route_table_association = "disable"` and `default_route_table_propagation = "disable"` are set on every TGW. Every attachment must explicitly declare:
- `aws_ec2_transit_gateway_route_table_association`
- `aws_ec2_transit_gateway_route_table_propagation`

This prevents accidental cross-environment routing and creates a full audit trail in code.

---

## State Management

Three separate state files per region:

| State File | Contains |
|------------|----------|
| `env-networking/{region}-tgw/terraform.tfstate` | TGW core + route tables |
| `env-networking/{region}-tgw-vpc-atts/terraform.tfstate` | VPC attachments |
| `env-{environment}/{region}/terraform.tfstate` | Individual VPCs |

**Backend configuration**:
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

States are bridged using `terraform_remote_state` data sources.

---

## Subnet Selection

- **Private subnets only** — TGW is internal infrastructure; no internet access needed
- **One subnet per AZ** — Ensures HA; traffic fails over automatically if one AZ is lost
- **Minimum /28 per subnet** — TGW uses 1 IP per ENI; AWS reserves 5; /28 provides adequate buffer

---

## ASN Assignment

ASNs are assigned from the private BGP range (64512–65534):

| Region | ASN | Status |
|--------|-----|--------|
| eu-west-2 (London) | 64514 | Deployed |
| us-east-1 (N. Virginia) | 64515 | Reserved |
| ap-southeast-1 (Singapore) | 64516 | Reserved |

Each TGW has a unique ASN to enable future inter-region TGW peering.

---

## Cost

| Component | Cost |
|-----------|------|
| Transit Gateway | ~$36/month ($0.05/hour) |
| VPC Attachment | ~$36/month per attachment |
| Data Transfer | $0.02/GB processed |

**Use TGW when**: 4+ VPCs need full-mesh connectivity (cheaper than N² peering connections).
**Use VPC Peering when**: Simple 2-VPC connectivity ($0.01/GB, no hourly charge).

---

## Scalability

AWS limits per TGW: 5,000 attachments, 10,000 routes per route table, 20 route tables.

Scaling path: horizontal (more VPCs on same TGW) → regional (new TGW per region) → multi-region peering.

---

## Future Enhancements

| Phase | Goal |
|-------|------|
| 2 | Add routes in VPC private route tables pointing to TGW (`10.0.0.0/8 → tgw-id`) |
| 3 | Deploy production VPC and attach to `rt-tgw-euw2-prod` |
| 4 | Shared Services VPC (centralized DNS, monitoring, logging) |
| 5 | AWS Managed Prefix Lists to simplify route management at scale |
| 6 | Multi-region TGW peering (tgw-euw2 ↔ tgw-use1) |
| 7 | AWS Network Manager for centralized global visibility |

---

## Validation

```bash
# Check TGW status
aws ec2 describe-transit-gateways \
  --transit-gateway-ids tgw-0530e685d439e1f8d

# List route tables
aws ec2 describe-transit-gateway-route-tables \
  --filters "Name=transit-gateway-id,Values=tgw-0530e685d439e1f8d"

# Verify route table is empty
aws ec2 search-transit-gateway-routes \
  --transit-gateway-route-table-id tgw-rtb-02085d749182ff497 \
  --filters "Name=state,Values=active"
```

---

## Troubleshooting

| Issue | Resolution |
|-------|-----------|
| TGW creation times out | Check service quota (default: 5 TGWs per account); verify `ec2:CreateTransitGateway` IAM permission |
| Route table not created | Route tables depend on TGW ID — ensure TGW completed before retrying |
| ASN conflict | Choose a different ASN from 64512–65534; document the assignment |
| Data source fails | Ensure the referenced state file has the required outputs; run the TGW stack first |

---

## Lessons Learned

1. **Plan outputs upfront** — Downstream modules needed `vpc_id` and `private_subnet_ids`; adding them later required a separate apply cycle.
2. **Test state bridging early** — `terraform_remote_state` data sources failed initially due to missing outputs in the referenced state.
3. **Establish naming conventions before writing code** — Early drafts had inconsistent patterns that required a refactor pass.

---

## References

- [AWS Transit Gateway Documentation](https://docs.aws.amazon.com/vpc/latest/tgw/what-is-transit-gateway.html)
- [TGW VPC Attachment Module](../tgw-vpc-peering-attachments.md)
- RFC 6996: Private ASN Range (64512–65534)

---

## Change Log

| Date | Version | Changes |
|------|---------|---------|
| 2026-02-12 | 1.0 | Initial design decisions documented |
| 2026-03-11 | 2.0 | Merged tgw-module.md into this document; removed redundant content |
