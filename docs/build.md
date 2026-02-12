# Build & Teardown Guide

## Full Deployment Order

```bash
# 1. Deploy VPC with all resources
cd envs/dev/euw2/cell1000/
terraform init && terraform apply

# 2. Deploy Transit Gateway
cd envs/networking/euw2/tgw/
terraform init && terraform apply

# 3. Deploy VPC attachments
cd envs/networking/euw2/tgw-vpc-atts/
terraform init && terraform apply
```

## Complete Teardown

**CRITICAL**: Destroy in reverse order to avoid dependency errors.

### Step 1: Delete TGW VPC Attachments

```bash
cd envs/networking/euw2/tgw-vpc-atts/
terraform destroy -auto-approve
```

**Deletes**: VPC attachments, route table associations, propagations
**Duration**: ~3 min | **Saves**: $36/month per attachment

### Step 2: Delete Transit Gateway

```bash
cd envs/networking/euw2/tgw/
terraform destroy -auto-approve
```

**Deletes**: Transit Gateway, route tables (prod/dev/shared)
**Duration**: ~2 min | **Saves**: $36/month

### Step 3: Delete VPC & All Resources

```bash
cd envs/dev/euw2/cell1000/
terraform destroy -auto-approve
```

**Deletes**:
- 6 EC2 instances (bastion hosts)
- 3 EC2 instances (private hosts)
- NAT Gateway, Internet Gateway, Egress-only IGW
- 6 subnets (3 public, 3 private)
- Route tables, routes, route table associations
- Security groups (bastion, private), NACLs with rules
- SSH key pair (AWS key + local files)
- VPC

**Duration**: ~5-7 min | **Saves**: ~$150-200/month (EC2 + NAT)

## Verification

```bash
# No TGW attachments
aws ec2 describe-transit-gateway-vpc-attachments --region eu-west-2

# No TGW
aws ec2 describe-transit-gateways --region eu-west-2

# No VPC
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=vpc-euw2-dev-cell1000" --region eu-west-2
```

Expected: Empty results `[]` or "not found" errors.
