# NAT Gateway Deployment Timeout (AWSCC Provider)

## Background

NAT Gateways in this project are created using `awscc_ec2_nat_gateway` (the AWS Cloud Control API
provider) rather than the standard `aws_nat_gateway`. This is because Regional Auto Mode
(`availability_mode = "regional"`) is only available through the AWSCC provider. In this mode, AWS
automatically manages Elastic IP addresses across availability zones — no manual EIP allocation is
required — and a single NAT Gateway per VPC provides high availability.

## The Problem

The AWSCC provider does not have the same built-in retry and backoff logic as the standard `aws`
provider. When a VPC is freshly created, the VPC ID may not yet be visible to all Cloud Control API
endpoints. If the NAT Gateway creation request fires before the VPC has fully propagated, the Cloud
Control API returns:

```
StatusMessage: The vpc ID 'vpc-xxxxxxxxxxxxxxxxx' does not exist
(Service: Ec2, Status Code: 400, ErrorCode: InvalidRequest)
```

This race condition was observed consistently in eu-west-1. It is less likely in eu-west-2 because
the Cloud Control API endpoints in that region propagate VPC state faster, but the underlying
limitation applies to any region.

## The Workaround

A `time_sleep` resource in `modules/create-vpc/gateways.tf` gates NAT Gateway creation:

```hcl
resource "time_sleep" "wait_for_vpc" {
  depends_on      = [aws_vpc.this]
  create_duration = "10s"

  triggers = {
    vpc_id = aws_vpc.this.id
  }
}

resource "awscc_ec2_nat_gateway" "this" {
  vpc_id = time_sleep.wait_for_vpc.triggers["vpc_id"]
  ...
}
```

The VPC ID is threaded through `time_sleep.triggers` rather than referenced directly. This makes the
dependency explicit in Terraform's resource graph and ensures the wait is enforced even if Terraform
attempts to parallelise resource creation.

## Why 10 Seconds

The timeout started at 15 seconds as a conservative estimate and was reduced to 10 seconds after
confirming it was sufficient. In practice this adds negligible overhead — the NAT Gateway itself
takes several minutes to reach `available` state after creation.

## Removing the Timeout

The `time_sleep` can only be safely removed by switching from `awscc_ec2_nat_gateway` to
`aws_nat_gateway`. The standard provider has proper retry logic and would not encounter this race
condition. The trade-off is that `aws_nat_gateway` does not support `availability_mode = "regional"`,
which means losing the auto-managed EIP high-availability feature and having to allocate EIPs
manually.

Reducing the duration below 10 seconds is possible but risks intermittent failures in regions where
VPC propagation is slower.
