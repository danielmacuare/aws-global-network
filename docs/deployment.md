# Deployment Instructions

## Deploy to Development Environment (EU West 2)

1. **Navigate to the environment directory:**

   ```bash
   cd envs/dev/euw2
   ```

2. **Initialize Terraform:**

   ```bash
   terraform init
   ```

3. **Review the deployment plan:**

   ```bash
   terraform plan -var-file="variables.tfvars"
   ```

4. **Apply the configuration:**

   ```bash
   terraform apply -var-file="variables.tfvars"
   ```

5. **Verify deployment:**

   ```bash
   terraform show
   ```

## Deploy to Additional Regions

To deploy to a new region:

1. **Create a new environment directory:**

   ```bash
   mkdir -p envs/dev/use1  # For US East 1
   ```

2. **Copy configuration files:**

   ```bash
   cp envs/dev/euw2/* envs/dev/use1/
   ```

3. **Update region-specific values:**
   - Update `variables.tfvars` with new region
   - Update `backend.tf` with new state key
   - Update `locals.tf` with new region

4. **Deploy using the same steps above**

## Module Usage

### VPC Module

The `create-vpc` module creates:

- VPC with configurable CIDR
- Public and private subnets across multiple AZs
- Route tables and NAT gateways
- Consistent tagging

Example usage:

```hcl
module "vpc-main" {
  source = "../../../modules/create-vpc/"

  aws_region       = "eu-west-2"
  aws_region_short = "euw2"
  environment      = "dev"
  vpc_name         = "main"
  vpc_cidr         = "10.0.0.0/20"

  private_subnets = {
    priv-0 = {
      az          = "eu-west-2a"
      cidr        = "10.0.0.0/24"
      nat_gateway = true
    }
  }

  public_subnets = {
    pub-0 = {
      az          = "eu-west-2a"
      cidr        = "10.0.10.0/24"
      nat_gateway = false
    }
  }
}
```

## Troubleshooting

### Common Issues

1. **Backend initialization fails:**
   - Ensure S3 bucket exists and you have access
   - Check AWS credentials are configured

2. **Plan fails with permission errors:**
   - Verify AWS IAM permissions for VPC, subnet, and route table operations

3. **State lock errors:**
   - Check if another deployment is running
   - Manually unlock if needed: `terraform force-unlock <lock-id>`