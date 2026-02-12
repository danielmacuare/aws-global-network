# Getting Started

## Prerequisites

- **Terraform**: Version >= 1.2.1
- **AWS CLI**: Configured with appropriate credentials
- **AWS Account**: With permissions to create VPCs, subnets, route tables, and Transit Gateways
- **S3 Bucket**: For Terraform state storage (update `backend.tf` with your bucket name)

## Initial Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd aws-poc
```

### 2. Configure Backend Storage

Update the S3 bucket name in `envs/dev/euw2/cell1000/backend.tf`:

```hcl
terraform {
  backend "s3" {
    region = "eu-west-2"
    bucket = "your-terraform-state-bucket"  # Update this
    key    = "env-dev/euw2/cell1000/terraform.tfstate"
  }
}
```

### 3. Review Configuration

Check the configuration in `envs/dev/euw2/cell1000/variables.tfvars`:

```hcl
region       = "eu-west-2"
region_short = "euw2"
environment      = "dev"
```

## Development Workflow

### Before Making Changes

```bash
# Format Terraform files
terraform fmt -recursive

# Validate configuration
terraform validate

# Check for security issues (if tfsec is installed)
tfsec .
```

### Making Changes

1. **Create a feature branch:**

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes to the appropriate files**

3. **Test your changes:**

   ```bash
   cd envs/dev/euw2/cell1000
   terraform plan -var-file="variables.tfvars"
   ```

4. **Commit and push:**

   ```bash
   git add .
   git commit -m "Description of changes"
   git push origin feature/your-feature-name
   ```

5. **Create a Pull Request**

## Cleanup

To destroy the infrastructure:

```bash
cd envs/dev/euw2/cell1000
terraform destroy -var-file="variables.tfvars"
```