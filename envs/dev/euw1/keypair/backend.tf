# A backend block cannot refer to named values (like input variables, locals, or data source attributes).
terraform {
  backend "s3" {
    region       = "eu-west-1"
    bucket       = "dmac-bootstrap-tfstate"
    key          = "env-dev/euw1/keypair/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
