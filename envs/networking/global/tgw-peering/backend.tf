terraform {
  backend "s3" {
    region       = "eu-west-2"
    bucket       = "dmac-bootstrap-tfstate"
    key          = "env-networking/global-tgw-peering/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
