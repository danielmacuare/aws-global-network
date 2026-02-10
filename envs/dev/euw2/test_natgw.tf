# Regional NAT Gateway in auto mode with public connectivity
#resource "awscc_ec2_nat_gateway" "main" {
#vpc_id            = module.vpc-main.vpc.id
#connectivity_type = "public"
#availability_mode = "regional"

#tags = [
#{
#key   = "Name"
#value = "test-regional-ngw-euw2-dev"
#},
#{
#key   = "Environment"
#value = "dev"
#},
#{
#key   = "Region"
#value = "eu-west-2"
#},
#{
#key   = "Type"
#value = "regional-auto"
#},
#{
#key   = "ManagedBy"
#value = "AWSCC"
#}
#]
#}

## EIP for the Regional NAT Gateway (auto mode will handle AZ distribution)
#resource "awscc_ec2_eip" "main" {
#domain = "vpc"

#tags = [
#{
#key   = "Name"
#value = "test-eip-regional-ngw-euw2-dev"
#},
#{
#key   = "Environment"
#value = "dev"
#},
#{
#key   = "Region"
#value = "eu-west-2"
#},
#{
#key   = "ManagedBy"
#value = "AWSCC"
#}
#]
#}