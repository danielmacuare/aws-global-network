output "vpc_attachment" {
  description = "Full VPC attachment resource object"
  value       = aws_ec2_transit_gateway_vpc_attachment.this
}

output "attachment_id" {
  description = "VPC attachment ID"
  value       = aws_ec2_transit_gateway_vpc_attachment.this.id
}
