# Global Variables, Symlinked to each env/region
## Global Vars


## Regional Vars
variable "region" {
  type        = string
  description = "Target Region to deploy the resources"
  default     = null
}

variable "region_short" {
  type        = string
  description = "(Shorter Version) Target Region to deploy the resources. ie. use1, use2, euw2, etc"
  default     = null
}

## Environment Vars
variable "environment" {
  type        = string
  description = "Target environment to deploy the resources. i.e prod, dev, stage, etc"
  default     = null
}
