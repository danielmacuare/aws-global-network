locals {
  private_subnets_tag = "private"
  public_subnets_tag  = "public"

  # Convert default_tags map to AWSCC list format
  default_tags_awscc = [
    for key, value in var.default_tags : {
      key   = key
      value = value
    }
  ]
}