terraform {
  backend "s3" {
    bucket       = "dmac-bootstrap-tfstate"
    key          = "bootstrap/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true

  }
}