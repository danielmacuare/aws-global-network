terraform {
  backend "s3" {
    region       = "eu-west-2"
    bucket       = "dmac-bootstrap-tfstate"
    key          = "env-prod/euw2/cell0000/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
