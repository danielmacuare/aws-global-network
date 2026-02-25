terraform {
  backend "s3" {
    region       = "eu-west-2"
    bucket       = "dmac-bootstrap-tfstate"
    key          = "env-dev/euw1/cell3000/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
