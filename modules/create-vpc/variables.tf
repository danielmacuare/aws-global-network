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
variable "vpc_cidr" {
  type        = string
  description = "CIDR for the VPC"
}

variable "private_subnets" {
  type        = map(map(string))
  description = "Map including private subnets, their AZs and their CIDRs"
}

variable "public_subnets" {
  type        = map(map(string))
  description = "Map including public subnets, their AZs and their CIDRs"
}

## Optionals
variable "assign_generated_ipv6_cidr_block" {
  type        = bool
  description = "Requests an Amazon-provided IPv6 CIDR block with a /56 prefix length for the VPC. You cannot specify the range of IP addresses, or the size of the CIDR block"
  default     = false
}
