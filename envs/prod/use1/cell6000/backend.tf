terraform {
  backend "s3" {
    region       = "eu-west-2"
    bucket       = "dmac-bootstrap-tfstate"
    key          = "env-prod/use1/cell6000/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
