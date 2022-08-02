locals {
  region = "eu-west-2"

  private_subnets = {

    priv-0 = {
      az          = "${local.region}a"
      cidr        = "10.0.0.0/24"
      nat_gateway = true
    }

    priv-1 = {
      az          = "${local.region}b"
      cidr        = "10.0.1.0/24"
      nat_gateway = true
    }

    priv-2 = {
      az          = "${local.region}c"
      cidr        = "10.0.2.0/24"
      nat_gateway = true
    }
  }
}
