variable "default_tags" {
  description = "Standard project tags"
  type        = map(string)
}

variable "transit_gateway_id" {
  description = "Transit Gateway ID to attach to"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to attach"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the attachment (one per AZ)"
  type        = list(string)
}

variable "transit_gateway_route_table_id" {
  description = "Transit Gateway route table ID to associate with"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod, shared)"
  type        = string
}

variable "region_short" {
  description = "Short region code (e.g., euw2)"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC for attachment naming"
  type        = string
}

variable "dns_support" {
  description = "Enable DNS support for the attachment"
  type        = string
  default     = "enable"
}

variable "appliance_mode_support" {
  description = "Enable appliance mode support for the attachment"
  type        = string
  default     = "disable"
}

variable "private_route_table_ids" {
  description = "Map of private route table IDs (key → rtb-id) to add a TGW supernet route to. Required for VPC instances to send east-west traffic through the TGW."
  type        = map(string)
  default     = {}
}

variable "tgw_supernet_cidr" {
  description = "Supernet CIDR routed to the TGW from each private subnet route table (e.g. 10.0.0.0/8 covers all cells across all regions)."
  type        = string
  default     = "10.0.0.0/8"
}
