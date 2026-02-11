output "key_pair_name" {
  description = "The AWS key pair name"
  value       = aws_key_pair.this.key_name
}

output "key_pair_arn" {
  description = "The AWS key pair ARN"
  value       = aws_key_pair.this.arn
}
