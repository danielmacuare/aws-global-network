terraform {
  backend "s3" {
    region       = "eu-west-2"
    bucket       = "dmac-bootstrap-tfstate"
    key          = "env-prod/usw2/keypair/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
