terraform {
  backend "s3" {
    region       = "eu-west-2"
    bucket       = "dmac-bootstrap-tfstate"
    key          = "env-dev/usw2/cell5001/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
