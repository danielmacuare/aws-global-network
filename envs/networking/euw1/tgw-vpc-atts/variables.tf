variable "backend_bucket" {
  type        = string
  description = "S3 bucket name for Terraform remote state"
  default     = "dmac-bootstrap-tfstate"
}
