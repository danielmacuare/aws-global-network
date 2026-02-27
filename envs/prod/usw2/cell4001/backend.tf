terraform {
  backend "s3" {
    region       = "eu-west-2"
    bucket       = "dmac-bootstrap-tfstate"
    key          = "env-prod/usw2/cell4001/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
