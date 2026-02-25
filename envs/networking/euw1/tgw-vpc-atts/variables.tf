variable "target_environment" {
  type        = string
  description = "Target environment for VPC attachments (dev, prod)"
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.target_environment)
    error_message = "Environment must be either 'dev' or 'prod'."
  }
}

variable "backend_bucket" {
  type        = string
  description = "S3 bucket name for Terraform remote state"
  default     = "dmac-bootstrap-tfstate"
}
