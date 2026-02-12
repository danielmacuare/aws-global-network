variable "project_root" {
  type        = string
  description = "Absolute path to project root where ssh-keys folder will be created"
}

variable "region_short" {
  type        = string
  description = "Short region code (euw2, use1, etc.)"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, prod, stage, etc.)"
}

variable "default_tags" {
  type        = map(string)
  description = "Default tags to apply to resources"
}
