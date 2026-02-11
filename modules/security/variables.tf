variable "vpc_id" {
  type        = string
  description = "VPC ID where security groups will be created"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block for private security group rules"
}

variable "default_tags" {
  type        = map(string)
  description = "Default tags to apply to all security group resources"
}

variable "aws_region_short" {
  type        = string
  description = "Short region code for naming"
}

variable "environment" {
  type        = string
  description = "Environment name for naming"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "List of public subnet IDs"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs"
}
