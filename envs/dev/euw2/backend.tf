# A backend block cannot refer to named values (like input variables, locals, or data source attributes).
terraform {
  backend "s3" {
    region = "eu-west-2"
    bucket = "dmac-tformstate-test"
    key    = "env-dev/euw2/terraform.tfstate"
  }

}