data "aws_key_pair" "this" {
  key_name = "kp-${local.region_short}-${local.environment}"
}
