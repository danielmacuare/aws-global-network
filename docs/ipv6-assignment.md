# IPv6 CIDR Assignment Strategy

## Overview

This document explains how IPv6 CIDR blocks are automatically assigned to subnets within our VPC infrastructure. Our implementation uses AWS-provided IPv6 blocks with automatic subnet allocation to ensure proper dual-stack (IPv4 + IPv6) networking.

## Architecture

### VPC-Level IPv6 Assignment

When `assign_generated_ipv6_cidr_block = true` is set on the VPC resource, AWS automatically assigns a `/56` IPv6 CIDR block from Amazon's global IPv6 address pool.

**Example VPC IPv6 Block:**
```
2600:1f13:6c4:8a00::/56
```

**Key Characteristics:**
- **Size**: `/56` provides 256 `/64` subnets (2^8 = 256)
- **Source**: AWS Global Unicast Address (GUA) space
- **Scope**: Globally routable on the internet
- **Assignment**: Automatic, managed by AWS

### Subnet-Level IPv6 Assignment

Each subnet receives a `/64` IPv6 CIDR block carved from the VPC's `/56` block. This is the standard subnet size for IPv6 networks.

## Implementation Details

### Terraform Configuration

```terraform
resource "aws_subnet" "private" {
  for_each = var.private_subnets

  # IPv4 configuration
  cidr_block        = each.value["cidr"]
  
  # IPv6 configuration
  ipv6_cidr_block                         = var.assign_generated_ipv6_cidr_block ? 
    cidrsubnet(aws_vpc.this.ipv6_cidr_block, 8, index(keys(var.private_subnets), each.key)) 
    : null
  assign_ipv6_address_on_creation         = true
  enable_resource_name_dns_aaaa_record_on_launch = true
  
  # ... other attributes
}
```

### CIDR Calculation Function

The `cidrsubnet()` function calculates subnet IPv6 blocks:

```terraform
cidrsubnet(prefix, newbits, netnum)
```

**Parameters:**
- `prefix`: VPC's IPv6 CIDR block (e.g., `2600:1f13:6c4:8a00::/56`)
- `newbits`: Number of bits to add to the prefix (8 bits: /56 → /64)
- `netnum`: Subnet index number (0, 1, 2, 3...)

**Example Calculation:**
```
cidrsubnet("2600:1f13:6c4:8a00::/56", 8, 0) = "2600:1f13:6c4:8a00::/64"
cidrsubnet("2600:1f13:6c4:8a00::/56", 8, 1) = "2600:1f13:6c4:8a01::/64"
cidrsubnet("2600:1f13:6c4:8a00::/56", 8, 2) = "2600:1f13:6c4:8a02::/64"
```

### Index Calculation

**Private Subnets:**
```terraform
index(keys(var.private_subnets), each.key)
```
- Returns the position of the subnet in the map
- `priv-0` → index 0
- `priv-1` → index 1
- `priv-2` → index 2

**Public Subnets:**
```terraform
index(keys(var.public_subnets), each.key) + length(var.private_subnets)
```
- Offsets by the number of private subnets to prevent overlap
- If 3 private subnets exist:
  - `pub-0` → index 3 (0 + 3)
  - `pub-1` → index 4 (1 + 3)
  - `pub-2` → index 5 (2 + 3)

## Allocation Example

### Given Configuration

**VPC:**
- IPv6 CIDR: `2600:1f13:6c4:8a00::/56`

**Subnets:**
- 3 Private subnets (priv-0, priv-1, priv-2)
- 3 Public subnets (pub-0, pub-1, pub-2)

### Resulting IPv6 Allocations

| Subnet | Type | Index | IPv6 CIDR Block | Calculation |
|--------|------|-------|-----------------|-------------|
| priv-0 | Private | 0 | `2600:1f13:6c4:8a00::/64` | cidrsubnet(vpc, 8, 0) |
| priv-1 | Private | 1 | `2600:1f13:6c4:8a01::/64` | cidrsubnet(vpc, 8, 1) |
| priv-2 | Private | 2 | `2600:1f13:6c4:8a02::/64` | cidrsubnet(vpc, 8, 2) |
| pub-0  | Public  | 3 | `2600:1f13:6c4:8a03::/64` | cidrsubnet(vpc, 8, 3) |
| pub-1  | Public  | 4 | `2600:1f13:6c4:8a04::/64` | cidrsubnet(vpc, 8, 4) |
| pub-2  | Public  | 5 | `2600:1f13:6c4:8a05::/64` | cidrsubnet(vpc, 8, 5) |

### Address Space Utilization

- **Used**: 6 out of 256 available `/64` subnets (2.3%)
- **Available**: 250 `/64` subnets for future expansion
- **Per Subnet**: 2^64 addresses (18,446,744,073,709,551,616 addresses)

## IPv6 Features Enabled

### 1. Automatic IPv6 Assignment

```terraform
assign_ipv6_address_on_creation = true
```

**Behavior:**
- EC2 instances automatically receive an IPv6 address when launched
- No manual configuration required
- Dual-stack: Instances have both IPv4 and IPv6

**Example Instance Addresses:**
- IPv4: `10.0.0.45`
- IPv6: `2600:1f13:6c4:8a00::1a3`

### 2. DNS AAAA Records

```terraform
enable_resource_name_dns_aaaa_record_on_launch = true
```

**Behavior:**
- Automatically creates DNS AAAA records (IPv6 equivalent of A records)
- Enables DNS resolution for IPv6 addresses
- Works with Route 53 private hosted zones

**Example DNS Records:**
```
ip-10-0-0-45.eu-west-2.compute.internal    A     10.0.0.45
ip-10-0-0-45.eu-west-2.compute.internal    AAAA  2600:1f13:6c4:8a00::1a3
```

## Routing Configuration

### Private Subnets

**IPv4 Routing:**
```terraform
resource "aws_route" "private_default" {
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = awscc_ec2_nat_gateway.this.nat_gateway_id
}
```
- Routes IPv4 traffic through Regional NAT Gateway
- Provides outbound internet access
- Hides private IPv4 addresses

**IPv6 Routing:**
```terraform
resource "aws_route" "private_ipv6_egress" {
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = aws_egress_only_internet_gateway.this.id
}
```
- Routes IPv6 traffic through Egress-only Internet Gateway
- Allows outbound IPv6 connections
- Blocks inbound IPv6 connections (stateful)
- No NAT required (IPv6 addresses are globally unique)

### Public Subnets

**IPv4 Routing:**
```terraform
resource "aws_route" "public_default" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}
```
- Routes IPv4 traffic through Internet Gateway
- Bidirectional internet access

**IPv6 Routing:**
```terraform
resource "aws_route" "public_ipv6" {
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.this.id
}
```
- Routes IPv6 traffic through Internet Gateway
- Bidirectional internet access
- No NAT required

## Benefits of This Approach

### 1. Automatic Management
- AWS handles IPv6 block assignment
- No manual CIDR planning required
- Consistent allocation across regions

### 2. Scalability
- 256 available `/64` subnets per VPC
- Each subnet supports 2^64 addresses
- Room for massive expansion

### 3. Dual-Stack Support
- Instances support both IPv4 and IPv6
- Gradual migration path from IPv4 to IPv6
- Compatibility with legacy systems

### 4. No IPv6 NAT Required
- IPv6 addresses are globally unique
- Direct routing without address translation
- Simplified network architecture
- Better performance (no NAT overhead)

### 5. Future-Proof
- IPv6 is the long-term internet standard
- IPv4 address exhaustion mitigation
- Modern application compatibility

## Security Considerations

### Egress-Only Internet Gateway

**Purpose:**
- Allows outbound IPv6 connections from private subnets
- Blocks unsolicited inbound IPv6 connections
- Stateful firewall behavior

**Use Case:**
- Private instances need to download updates
- Applications need to call external APIs
- No need for inbound internet access

### Security Groups

IPv6 security group rules must be explicitly configured:

```terraform
# Allow outbound IPv6 HTTPS
egress {
  from_port        = 443
  to_port          = 443
  protocol         = "tcp"
  ipv6_cidr_blocks = ["::/0"]
}

# Block inbound IPv6 by default
# (no ingress rules = deny all)
```

### Network ACLs

Consider IPv6-specific NACL rules:

```terraform
# Allow outbound IPv6
egress {
  rule_no         = 110
  protocol        = "-1"
  action          = "allow"
  ipv6_cidr_block = "::/0"
  from_port       = 0
  to_port         = 0
}
```

## Troubleshooting

### Verify IPv6 Assignment

**Check VPC IPv6 CIDR:**
```bash
aws ec2 describe-vpcs --vpc-ids vpc-xxxxx \
  --query 'Vpcs[0].Ipv6CidrBlockAssociationSet'
```

**Check Subnet IPv6 CIDR:**
```bash
aws ec2 describe-subnets --subnet-ids subnet-xxxxx \
  --query 'Subnets[0].Ipv6CidrBlockAssociationSet'
```

**Check Instance IPv6 Address:**
```bash
aws ec2 describe-instances --instance-ids i-xxxxx \
  --query 'Reservations[0].Instances[0].NetworkInterfaces[0].Ipv6Addresses'
```

### Test IPv6 Connectivity

**From EC2 Instance:**
```bash
# Test IPv6 connectivity
ping6 -c 4 ipv6.google.com

# Check IPv6 address
ip -6 addr show

# Test IPv6 route
ip -6 route show
```

### Common Issues

**Issue: Subnet has no IPv6 CIDR**
- **Cause**: `assign_generated_ipv6_cidr_block` not set on VPC
- **Solution**: Enable IPv6 on VPC and recreate subnets

**Issue: Instances not getting IPv6 addresses**
- **Cause**: `assign_ipv6_address_on_creation` not enabled
- **Solution**: Enable on subnet and relaunch instances

**Issue: IPv6 connectivity not working**
- **Cause**: Missing routes or security group rules
- **Solution**: Verify route tables and security groups allow IPv6

## References

- [AWS VPC IPv6 Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-ipv6.html)
- [Terraform cidrsubnet Function](https://www.terraform.io/language/functions/cidrsubnet)
- [IPv6 Address Planning](https://www.rfc-editor.org/rfc/rfc4291.html)
- [Egress-only Internet Gateway](https://docs.aws.amazon.com/vpc/latest/userguide/egress-only-internet-gateway.html)
