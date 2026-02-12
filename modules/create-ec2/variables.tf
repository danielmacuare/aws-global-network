variable "default_tags" {
  type        = map(string)
  description = "Default tags to apply to all resources"
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
variable "vpc_id" {
  type        = string
  description = "VPC ID where EC2 instances will be created (needed to find default security group)"
}

variable "public_subnets" {
  type        = map(any)
  description = "Map of public subnets for bastion instances"
}

variable "private_subnets" {
  type        = map(any)
  description = "Map of private subnets for private instances"
}

variable "key_pair_name" {
  type        = string
  description = "Name of the SSH key pair to use for EC2 instances"
}

## Optional
variable "public_security_group_id" {
  type        = string
  description = "Security group ID for bastion instances (uses VPC default if not provided)"
  default     = null
}

variable "private_security_group_id" {
  type        = string
  description = "Security group ID for private instances (uses VPC default if not provided)"
  default     = null
}

## Optionals
variable "bastion_instance_type" {
  type        = string
  description = "Instance type for bastion hosts (t2.micro is free tier eligible)"
  default     = "t2.micro"
}

variable "private_instance_type" {
  type        = string
  description = "Instance type for private instances (t2.micro is free tier eligible)"
  default     = "t2.micro"
}
