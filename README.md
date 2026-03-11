
# aws-global-network

![GH Actions workflow](https://github.com/danielmacuare/aws-global-network/actions/workflows/pipeline.yml/badge.svg)

This project builds a global network architecture using AWS Transit Gateway spanning multiple regions. The infrastructure is managed using Terraform modules with environment-specific configurations.

## Architecture

In our first iteration, we will build a Global Network based on the diagram below:

![Network Diagram](./resources/tgw-multi-region.png)

A full-mesh Transit Gateway network across 4 regions (eu-west-2, eu-west-1, us-west-2, us-east-1) with prod and dev VPC cells in each region, connected via 6 TGW peering attachments.

## Quick Start

- [Getting Started](docs/dev/getting-started.md) — prerequisites, clone, backend config, dev workflow
- [Deployment Guide](docs/dev/deployment.md) — deploy.py phases, CLI reference, destroy, verification

## Repository Structure

```text
├── docs/
│   ├── design/            # Architecture and design decisions
│   └── dev/               # Developer guides and operational docs
│       ├── connectivity/  # Connectivity test results
│       └── tools/         # CI/CD and development tool guides
├── envs/                  # Environment-specific Terraform configurations
│   ├── dev/               # Development environment (cells per region)
│   ├── prod/              # Production environment (cells per region)
│   └── networking/        # TGWs, TGW-VPC attachments, TGW peering
├── modules/               # Reusable Terraform modules
│   ├── create-ec2/        # Bastion and private EC2 instances
│   ├── create-key-pair/   # RSA key pair generation and AWS registration
│   ├── create-tgw/        # Transit Gateway with prod/dev/wan route tables
│   ├── create-tgw-vpc-attachment/ # TGW-VPC attachment and route propagation
│   ├── create-vpc/        # VPC with public/private subnets, NAT, IPv6
│   └── security/          # Security groups and network ACLs
├── scripts/               # Python deployment orchestration scripts
├── specs/                 # Feature planning and implementation history
├── vars/                  # Shared variable definitions
└── resources/             # Documentation assets
```

## Documentation

### Infrastructure Design

- [Network Design](docs/design/network-design.md) — IP allocation, TGW topology, ASNs, naming conventions
- [Transit Gateways](docs/design/tgws.md) — TGW modules, route tables, peering architecture
- [TGW VPC Attachments](docs/design/tgw-vpc-attachments.md) — attachment module reference
- [IPv6 Assignment](docs/design/ipv6-assignment.md) — dual-stack subnet CIDR strategy
- [Tagging Strategy](docs/design/tagging-strategy.md) — required tags, naming patterns, compliance
- [Terraform Standards](docs/design/terraform-standards.md) — code style, variable rules, module conventions

### Operations

- [Getting Started](docs/dev/getting-started.md) — prerequisites, setup, development workflow
- [Deployment](docs/dev/deployment.md) — full deploy/destroy reference, CLI flags, manual steps
- [SSH Key Pairs](docs/dev/key-pairs.md) — key generation, SSH access, troubleshooting
- [NAT Gateway Timeout](docs/dev/ngw-timeout.md) — AWSCC provider race condition workaround
- [Connectivity Results](docs/dev/connectivity/README.md) — 32/32 PASS across 4 regions

### Tools

- [Checkov](docs/dev/tools/checkov.md) — static security scanning
- [Infracost](docs/dev/tools/infracost.md) — cost estimation on PRs
- [Prek](docs/dev/tools/prek.md) — pre-commit hooks
- [terraform-docs](docs/dev/tools/terraform-docs.md) — auto-generated module documentation
- [tf-validate](docs/dev/tools/tf-validate.md) — parallel Terraform validate with timing output
- [tflint](docs/dev/tools/tflint.md) — Terraform linter
- [uv](docs/dev/tools/uv.md) — Python dependency management

## CI/CD Pipeline

The project includes a GitHub Actions pipeline (`pipeline.yml`) that runs on pushes to `main` and pull requests. Pipeline jobs include Terraform validate, tflint, terraform-docs, Checkov security scanning, and Infracost cost estimation with PR comments.

See [CI Pipeline](docs/dev/tools/ci-pipeline.md) for a full job breakdown, Mermaid diagram, and AWS OIDC authentication details.

## Modules

| Module | Description |
|--------|-------------|
| [create-ec2](modules/create-ec2/README.md) | Bastion (public) and private EC2 instances using Ubuntu 24.04 LTS |
| [create-key-pair](modules/create-key-pair/README.md) | RSA 4096-bit key pair generation and AWS EC2 registration |
| [create-tgw](modules/create-tgw/README.md) | Transit Gateway with prod, dev, and wan route tables |
| [create-tgw-vpc-attachment](modules/create-tgw-vpc-attachment/README.md) | TGW-VPC attachment, route table association, and supernet route propagation |
| [create-vpc](modules/create-vpc/README.md) | VPC with public/private subnets, Internet Gateway, NAT Gateway, and IPv6 egress |
| [security](modules/security/README.md) | Security groups and network ACLs for bastion and private instances |
