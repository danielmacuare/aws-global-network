
PROJECT_NAME=$HOME/repos/aws-global-network

## Build and test commands

terraform validate
terraform fmt --recursive $PROJECT_NAME
tflint --recursive --config=$PROJECT_NAME/tools/.tflint.hcl

## Code Style Guidelines

- Indentation: White spaces with 2 spaces for indentation.
- When creating resources in a module, use resource.this as a naming convention. Example: `resource "aws_vpc" "this"`
- Before adding new Terraform outputs or variables, check existing outputs/variables in the same module to avoid duplicates. Run `grep -r 'output "' <module_dir>/` before creating any new output blocks.

## Working with Terraform modules

- Always pin provider versions in a versions.tf file to prevent breaking changes when providers update.versions.tf
- Every variable must have a description and a type.
- Sensible Defaults: Only provide default values for variables that are truly optional; keep mandatory ones undefined to force explicit input.
- Consistent Outputs: Output the full resource objects or at least the IDs and ARNs so that the calling module has access to all necessary metadata.
- Use `sensitive = true` for variables that handle password or tokens.

## Terraform Patterns & Examples

## TO-DO

- Locals (The Logic & Topology))
  - Computed values (cidrsubnet, aws_short_region),etc

```terraform
locals {
  # 1. Computed Strings
  region_short = "euw1" # Or calculate this dynamically if preferred
  vpc_name     = "${local.region_short}-${var.environment}-${var.cell_name}"
  project_root = pathexpand("~/repos/aws-global-network")

  # 2. Reusable Metadata
  default_tags = {
    owning_team          = "NETENG"
    managed_by_terraform = true
    environment          = var.environment
    region               = var.region
    region_short         = local.region_short
    cell_name            = var.cell_name
  }

  # 3. Network Topology (Data Payloads)
  private_subnets = {
    priv-0 = {
      az          = "${var.region}a"
      cidr        = "10.17.16.0/24"
      nat_gateway = true
    }
    priv-1 = {
      az          = "${var.region}b"
      cidr        = "10.17.17.0/24"
      nat_gateway = true
    }
    priv-2 = {
      az          = "${var.region}c"
      cidr        = "10.17.18.0/24"
      nat_gateway = true
    }
  }

  public_subnets = {
    pub-0 = {
      az          = "${var.region}a"
      cidr        = "10.17.26.0/24"
      nat_gateway = false
    }
    pub-1 = {
      az          = "${var.region}b"
      cidr        = "10.17.27.0/24"
      nat_gateway = false
    }
    pub-2 = {
      az          = "${var.region}c"
      cidr        = "10.17.28.0/24"
      nat_gateway = false
    }
  }
}
```

- variables (The inputs)
  - Regional or env vars.

```terraform
variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "cell_name" {
  type    = string
  default = "cell3001"
}

variable "vpc_cidr" {
  description = "The base CIDR for the entire VPC"
  type        = string
  default     = "10.17.16.0/20"
}
```

- module
  - No hardoced values here

```terraform
module "vpc-main" {
  source = "../../../../modules/create-vpc/"

  # Pass Variables
  region      = var.region
  environment = var.environment
  cell_name   = var.cell_name
  vpc_cidr    = var.vpc_cidr

  # Pass Computed Locals
  region_short    = local.region_short
  vpc_name        = local.vpc_name
  default_tags    = local.default_tags
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  # Hardcoded Boolean Toggles (Module-specific settings)
  assign_generated_ipv6_cidr_block = true # Note: use boolean true, not string "true"
}
```

- cidrsubnet function to dinmaycally calculate the subnets/ Example below:

```terraform
locals {
  # ... (other locals remain the same) ...

  private_subnets = {
    priv-0 = {
      az          = "${var.region}a"
      cidr        = cidrsubnet(var.vpc_cidr, 4, 0)
      nat_gateway = true
    }
    priv-1 = {
      az          = "${var.region}b"
      cidr        = cidrsubnet(var.vpc_cidr, 4, 1)
      nat_gateway = true
    }
    priv-2 = {
      az          = "${var.region}c"
      cidr        = cidrsubnet(var.vpc_cidr, 4, 2)
      nat_gateway = true
    }
  }

  public_subnets = {
    pub-0 = {
      az          = "${var.region}a"
      cidr        = cidrsubnet(var.vpc_cidr, 4, 10)
      nat_gateway = false
    }
    pub-1 = {
      az          = "${var.region}b"
      cidr        = cidrsubnet(var.vpc_cidr, 4, 11)
      nat_gateway = false
    }
    pub-2 = {
      az          = "${var.region}c"
      cidr        = cidrsubnet(var.vpc_cidr, 4, 12)
      nat_gateway = false
    }
  }
}
```

- Data source and dynamic AZz

```terraform

# Fetches all currently healthy and available AZs in the current region
data "aws_availability_zones" "available" {
  state = "available"
}


# locals.tf
locals {
  # ... (other locals remain the same) ...

  private_subnets = {
    priv-0 = {
      az          = data.aws_availability_zones.available.names[0]
      cidr        = cidrsubnet(var.vpc_cidr, 4, 0)
      nat_gateway = true
    }
    priv-1 = {
      az          = data.aws_availability_zones.available.names[1]
      cidr        = cidrsubnet(var.vpc_cidr, 4, 1)
      nat_gateway = true
    }
    priv-2 = {
      az          = data.aws_availability_zones.available.names[2]
      cidr        = cidrsubnet(var.vpc_cidr, 4, 2)
      nat_gateway = true
    }
  }

  public_subnets = {
    pub-0 = {
      az          = data.aws_availability_zones.available.names[0]
      cidr        = cidrsubnet(var.vpc_cidr, 4, 10)
      nat_gateway = false
    }
    pub-1 = {
      az          = data.aws_availability_zones.available.names[1]
      cidr        = cidrsubnet(var.vpc_cidr, 4, 11)
      nat_gateway = false
    }
    pub-2 = {
      az          = data.aws_availability_zones.available.names[2]
      cidr        = cidrsubnet(var.vpc_cidr, 4, 12)
      nat_gateway = false
    }
  }
}


```
