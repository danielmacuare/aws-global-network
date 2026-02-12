variable "default_tags" {
  description = "Standard project tags"
  type        = map(string)
}

variable "region" {
  description = "Full AWS region name"
  type        = string
}

variable "region_short" {
  description = "Short region code (e.g., euw2)"
  type        = string
}

variable "amazon_side_asn" {
  description = "BGP ASN for the Transit Gateway"
  type        = number
}

variable "dns_support" {
  description = "Enable DNS support for Transit Gateway"
  type        = string
  default     = "enable"
}

variable "vpn_ecmp_support" {
  description = "Enable ECMP support for VPN connections"
  type        = string
  default     = "disable"
}

variable "default_route_table_association" {
  description = "Enable default route table association"
  type        = string
  default     = "disable"
}

variable "default_route_table_propagation" {
  description = "Enable default route table propagation"
  type        = string
  default     = "disable"
}

variable "multicast_support" {
  description = "Enable multicast support"
  type        = string
  default     = "disable"
}
