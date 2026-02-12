terraform {
  backend "s3" {
    region       = "eu-west-2"
    bucket       = "dmac-bootstrap-tfstate"
    key          = "env-networking/euw2-tgw-vpc-atts/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
