variable "default_tags" {
  default = {
    owning_team          = "NETENG"
    managed_by_terraform = true
  }
  type = map(string)
}

## Regional Vars
variable "aws_region" {
  type        = string
  description = "Target Region to deploy the resources"
}

variable "aws_region_short" {
  type        = string
  description = "(Shorter Version) Target Region to deploy the resources. ie. use1, use2, euw2, etc"
}

## Environment Vars
variable "environment" {
  type        = string
  description = "Target environment to deploy the resources. i.e prod, dev, stage, etc"
}

variable "vpc_name" {
  type        = string
  description = "Name of the VPC"
}

## Required
variable "public_subnets" {
  type        = map(any)
  description = "Map of public subnets for bastion instances"
}

variable "private_subnets" {
  type        = map(any)
  description = "Map of private subnets for private instances"
}

variable "public_security_group_id" {
  type        = string
  description = "Security group ID for bastion instances"
}

variable "private_security_group_id" {
  type        = string
  description = "Security group ID for private instances"
}

variable "key_pair_name" {
  type        = string
  description = "Name of the SSH key pair to use for EC2 instances"
}

## Optionals
variable "bastion_instance_type" {
  type        = string
  description = "Instance type for bastion hosts"
  default     = "t3.micro"
}

variable "private_instance_type" {
  type        = string
  description = "Instance type for private instances"
  default     = "t3.micro"
}
