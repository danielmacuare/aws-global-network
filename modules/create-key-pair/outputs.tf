output "key_pair_name" {
  description = "The AWS key pair name"
  value       = aws_key_pair.this.key_name
}

output "key_pair_arn" {
  description = "The AWS key pair ARN"
  value       = aws_key_pair.this.arn
}

output "key_pair_fingerprint" {
  description = "The AWS key pair fingerprint"
  value       = aws_key_pair.this.fingerprint
}

output "private_key_path" {
  description = "Local path to the private key file"
  value       = "${var.project_root}/ssh-keys/${var.region_short}-${var.environment}.pem"
}
