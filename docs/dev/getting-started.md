# Getting Started

## Prerequisites

- **Terraform**: Version >= 1.14.4 — use [tfenv](https://github.com/tfutils/tfenv) to manage versions locally. The repo root contains a `.terraform-version` file; `tfenv` picks it up automatically so `terraform` on your PATH always matches the CI version.
- **AWS CLI**: Configured with appropriate credentials
- **AWS Account**: With permissions to create VPCs, subnets, route tables, and Transit Gateways
- **S3 Bucket**: For Terraform state storage (update `backend.tf` with your bucket name)

## Initial Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd aws-global-network
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

## Terraform Version Management

The `.terraform-version` file at the repo root pins the Terraform CLI to `1.14.4`. If you use [tfenv](https://github.com/tfutils/tfenv), it reads this file automatically:

```bash
tfenv install   # installs the version in .terraform-version
tfenv use       # switches to it
terraform version  # should print 1.14.4
```

## Provider Lock Files

Every Terraform directory has a committed `.terraform.lock.hcl` file that pins exact provider versions. These lock files contain checksums for **both** `darwin_arm64` (local Mac) and `linux_amd64` (CI runners). If you upgrade a provider, regenerate checksums for both platforms:

```bash
terraform providers lock -platform=linux_amd64 -platform=darwin_arm64
```

Run this in every affected directory and commit the updated lock files.

## Development Workflow

### Before Making Changes

```bash
# Format Terraform files
terraform fmt -recursive

# Validate all Terraform directories in parallel (with timing output)
uv run --project scripts/ python scripts/tf_validate.py

# Run all pre-commit hooks against all files
prek -c tools/prek.yaml run --all-files
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