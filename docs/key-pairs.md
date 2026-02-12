# SSH Key Pair Management

## Overview

This document explains how SSH key pairs are generated, managed, and used for EC2 instance access in this project. The implementation uses Terraform to automatically generate RSA key pairs, store them locally, and register them with AWS.

## Architecture

### Key Pair Generation Flow

```
┌─────────────────────┐
│  tls_private_key    │  1. Generate RSA 4096-bit key pair
│  (Terraform)        │
└──────────┬──────────┘
           │
           ├─────────────────────────────────────┐
           │                                     │
           ▼                                     ▼
┌─────────────────────┐              ┌─────────────────────┐
│  local_file         │              │  aws_key_pair       │
│  (Private Key)      │              │  (Public Key)       │
│                     │              │                     │
│  Location:          │              │  Registered in AWS  │
│  ssh-keys/*.pem     │              │  EC2 Key Pairs      │
└─────────────────────┘              └─────────────────────┘
```

## Implementation Details

### Module Structure

```
modules/create-key-pair/
├── providers.tf      # AWS, TLS, and null providers
├── variables.tf      # Input variables
├── outputs.tf        # Key pair name, ARN, fingerprint, path
└── key-pair.tf       # Key generation and storage logic
```

### Key Generation Process

#### 1. Generate Private Key

```terraform
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
```

**Details:**
- **Algorithm**: RSA (industry standard for SSH)
- **Key Size**: 4096 bits (high security, recommended for production)
- **Provider**: HashiCorp TLS provider
- **Output**: Private key in PEM format, public key in OpenSSH format

#### 2. Create SSH Directory

```terraform
resource "null_resource" "create_ssh_dir" {
  provisioner "local-exec" {
    command     = "mkdir -p ${var.project_root}/ssh-keys"
    interpreter = ["/bin/sh", "-c"]
  }
}
```

**Purpose:**
- Ensures `ssh-keys/` directory exists before writing keys
- Uses `mkdir -p` for idempotent directory creation
- Runs on the local machine executing Terraform

#### 3. Save Private Key Locally

```terraform
resource "local_file" "private_key" {
  depends_on = [null_resource.create_ssh_dir]

  content         = tls_private_key.this.private_key_pem
  filename        = "${var.project_root}/ssh-keys/${var.aws_region_short}-${var.environment}.pem"
  file_permission = "0400"
}
```

**Details:**
- **Location**: `ssh-keys/{region_short}-{environment}.pem`
- **Permissions**: `0400` (read-only for owner, required by SSH)
- **Format**: PEM (Privacy Enhanced Mail)
- **Dependency**: Waits for directory creation

**Example Paths:**
- `ssh-keys/euw2-dev.pem`
- `ssh-keys/use1-prod.pem`
- `ssh-keys/euw1-stage.pem`

#### 4. Register Public Key with AWS

```terraform
resource "aws_key_pair" "this" {
  key_name   = "kp-${var.aws_region_short}-${var.environment}"
  public_key = tls_private_key.this.public_key_openssh

  tags = merge(
    var.default_tags,
    {
      Name = "kp-${var.aws_region_short}-${var.environment}"
    }
  )
}
```

**Details:**
- **Naming**: `kp-{region_short}-{environment}` (e.g., `kp-euw2-dev`)
- **Format**: OpenSSH public key format
- **Registration**: Stored in AWS EC2 Key Pairs service
- **Scope**: Regional (key pair exists per region)

## Idempotency

### How Terraform Handles Idempotency

Terraform automatically manages idempotency for key pair resources:

#### First Run (Create)
```bash
terraform apply
```
- Generates new RSA key pair
- Creates `ssh-keys/` directory
- Writes private key to local file
- Registers public key with AWS
- Stores key metadata in Terraform state

#### Subsequent Runs (No Changes)
```bash
terraform apply
# Output: No changes. Your infrastructure matches the configuration.
```

**Terraform checks:**
1. **State File**: Compares current state with desired configuration
2. **Key Pair Name**: Checks if `kp-{region}-{env}` exists in AWS
3. **Public Key**: Verifies public key matches what's in AWS
4. **Local File**: Checks if private key file exists with correct permissions

**Result**: If everything matches, Terraform makes no changes.

#### Handling Changes

**Scenario 1: Key Pair Deleted from AWS**
```bash
# Manually delete key pair from AWS Console
terraform apply
# Terraform will re-register the public key (same key pair)
```

**Scenario 2: Local Private Key Deleted**
```bash
# Manually delete ssh-keys/euw2-dev.pem
terraform apply
# Terraform will recreate the file from state
```

**Scenario 3: Terraform State Lost**
```bash
# State file deleted or corrupted
terraform apply
# ERROR: Key pair already exists in AWS
# Solution: Import existing key pair or delete from AWS
```

### Import Existing Key Pair

If you need to import an existing AWS key pair:

```bash
terraform import module.key_pair.aws_key_pair.this kp-euw2-dev
```

**Note**: You must have the private key file already in place.

## Usage

### Module Invocation

```terraform
module "key_pair" {
  source           = "../../../modules/create-key-pair"
  project_root     = local.project_root
  aws_region_short = local.region_short
  environment      = local.environment
  default_tags     = local.default_tags
}
```

### Using Key Pair with EC2 Instances

```terraform
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = module.key_pair.key_pair_name  # Reference the key pair
  
  # ... other configuration
}
```

### SSH Connection

```bash
# Connect to EC2 instance
ssh -i ssh-keys/euw2-dev.pem ubuntu@<instance-public-ip>

# With verbose output for debugging
ssh -v -i ssh-keys/euw2-dev.pem ubuntu@<instance-public-ip>
```

## Fingerprint Verification

### What is a Fingerprint?

A fingerprint is a short hash of the public key used to verify key authenticity. AWS displays the MD5 fingerprint in the EC2 console.

### Check Local Key Fingerprint (MD5)

#### Method 1: Using OpenSSL (Recommended)

```bash
# Generate MD5 fingerprint from private key
openssl pkey -in ssh-keys/euw2-dev.pem -pubout -outform DER | \
  openssl md5 -c
```

**Output:**
```
(stdin)= 12:34:56:78:9a:bc:de:f0:12:34:56:78:9a:bc:de:f0
```

#### Method 2: Using ssh-keygen

```bash
# Extract public key from private key
ssh-keygen -y -f ssh-keys/euw2-dev.pem > /tmp/temp_public_key.pub

# Generate MD5 fingerprint
ssh-keygen -l -E md5 -f /tmp/temp_public_key.pub

# Clean up
rm /tmp/temp_public_key.pub
```

**Output:**
```
4096 MD5:12:34:56:78:9a:bc:de:f0:12:34:56:78:9a:bc:de:f0 no comment (RSA)
```

#### Method 3: Using Terraform Output

```bash
# Get fingerprint from Terraform state
terraform output -json | jq -r '.key_pair_fingerprint.value'
```

**Output:**
```
12:34:56:78:9a:bc:de:f0:12:34:56:78:9a:bc:de:f0
```

### Verify Against AWS Console

1. Navigate to **EC2 Console** → **Key Pairs**
2. Find your key pair (e.g., `kp-euw2-dev`)
3. Compare the **Fingerprint** column with your local fingerprint
4. They should match exactly

### Verify Using AWS CLI

```bash
# Get key pair fingerprint from AWS
aws ec2 describe-key-pairs \
  --key-names kp-euw2-dev \
  --query 'KeyPairs[0].KeyFingerprint' \
  --output text
```

**Output:**
```
12:34:56:78:9a:bc:de:f0:12:34:56:78:9a:bc:de:f0
```

## Security Best Practices

### File Permissions

**Private Key:**
```bash
# Correct permissions (read-only for owner)
chmod 400 ssh-keys/euw2-dev.pem

# Verify permissions
ls -l ssh-keys/euw2-dev.pem
# Output: -r-------- 1 user group 3243 Feb 10 16:00 ssh-keys/euw2-dev.pem
```

**Why 0400?**
- SSH requires private keys to be readable only by the owner
- Prevents accidental modification or deletion
- Protects against unauthorized access

### Git Ignore

Ensure private keys are never committed to version control:

```gitignore
# .gitignore
ssh-keys/
*.pem
*.key
```

### Key Rotation

**Recommended Schedule:**
- **Development**: Every 6 months
- **Production**: Every 3 months
- **After Security Incident**: Immediately

**Rotation Process:**
1. Generate new key pair (change environment name or add version)
2. Update EC2 instances with new key
3. Test SSH access with new key
4. Remove old key pair from AWS
5. Delete old private key file
6. Update Terraform state

### Backup Strategy

**Private Keys:**
- Store in encrypted password manager (1Password, LastPass)
- Use encrypted backup storage (AWS Secrets Manager, HashiCorp Vault)
- Never store in plain text on shared drives

**Recovery:**
- If private key is lost, you cannot recover it
- You must generate a new key pair
- Update all EC2 instances using the old key

## Troubleshooting

### Permission Denied (publickey)

**Error:**
```
Permission denied (publickey).
```

**Solutions:**

1. **Check file permissions:**
   ```bash
   chmod 400 ssh-keys/euw2-dev.pem
   ```

2. **Verify correct key:**
   ```bash
   ssh -i ssh-keys/euw2-dev.pem ubuntu@<ip>
   ```

3. **Check instance key pair:**
   ```bash
   aws ec2 describe-instances --instance-ids i-xxxxx \
     --query 'Reservations[0].Instances[0].KeyName'
   ```

4. **Verify fingerprint matches:**
   ```bash
   # Local fingerprint
   openssl pkey -in ssh-keys/euw2-dev.pem -pubout -outform DER | openssl md5 -c
   
   # AWS fingerprint
   aws ec2 describe-key-pairs --key-names kp-euw2-dev \
     --query 'KeyPairs[0].KeyFingerprint' --output text
   ```

### Key Pair Already Exists

**Error:**
```
Error: InvalidKeyPair.Duplicate: The keypair 'kp-euw2-dev' already exists.
```

**Solutions:**

1. **Import existing key pair:**
   ```bash
   terraform import module.key_pair.aws_key_pair.this kp-euw2-dev
   ```

2. **Delete from AWS and recreate:**
   ```bash
   aws ec2 delete-key-pair --key-name kp-euw2-dev
   terraform apply
   ```

3. **Use different name:**
   - Change `environment` variable
   - Or modify key pair naming in module

### Wrong Fingerprint

**Issue:** Local fingerprint doesn't match AWS fingerprint

**Cause:** Different key pair registered in AWS

**Solution:**
1. Delete key pair from AWS
2. Run `terraform apply` to re-register
3. Verify fingerprints match

## Module Outputs

The key pair module provides the following outputs:

```terraform
output "key_pair_name" {
  description = "The AWS key pair name"
  value       = "kp-euw2-dev"
}

output "key_pair_arn" {
  description = "The AWS key pair ARN"
  value       = "arn:aws:ec2:eu-west-2:123456789012:key-pair/kp-euw2-dev"
}

output "key_pair_fingerprint" {
  description = "The AWS key pair fingerprint (MD5)"
  value       = "12:34:56:78:9a:bc:de:f0:12:34:56:78:9a:bc:de:f0"
}

output "private_key_path" {
  description = "Local path to the private key file"
  value       = "/path/to/project/ssh-keys/euw2-dev.pem"
}
```

## References

- [AWS EC2 Key Pairs Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html)
- [Terraform TLS Provider](https://registry.terraform.io/providers/hashicorp/tls/latest/docs)
- [OpenSSH Key Format](https://www.openssh.com/txt/rfc5656.txt)
- [SSH Best Practices](https://www.ssh.com/academy/ssh/key-management)
