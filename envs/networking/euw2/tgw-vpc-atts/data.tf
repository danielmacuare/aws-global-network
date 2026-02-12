# Read TGW state
data "terraform_remote_state" "tgw" {
  backend = "s3"
  config = {
    bucket = "dmac-bootstrap-tfstate"
    key    = "env-networking/euw2-tgw/terraform.tfstate"
    region = "eu-west-2"
  }
}

# Read Dev VPC state
data "terraform_remote_state" "dev_vpc" {
  backend = "s3"
  config = {
    bucket = "dmac-bootstrap-tfstate"
    key    = "env-dev/euw2/terraform.tfstate"
    region = "eu-west-2"
  }
}
