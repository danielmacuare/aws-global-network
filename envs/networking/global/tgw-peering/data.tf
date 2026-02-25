data "terraform_remote_state" "euw2_tgw" {
  backend = "s3"
  config = {
    region  = "eu-west-2"
    bucket  = "dmac-bootstrap-tfstate"
    key     = "env-networking/euw2-tgw/terraform.tfstate"
    encrypt = true
  }
}

data "terraform_remote_state" "euw1_tgw" {
  backend = "s3"
  config = {
    region  = "eu-west-2"
    bucket  = "dmac-bootstrap-tfstate"
    key     = "env-networking/euw1-tgw/terraform.tfstate"
    encrypt = true
  }
}
