output "key_pair_name" {
  description = "The AWS key pair name"
  value       = module.key_pair.key_pair_name
}

output "key_pair_path" {
  description = "Local path to the SSH private key"
  value       = module.key_pair.private_key_path
}
