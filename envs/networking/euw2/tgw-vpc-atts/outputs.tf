output "vpc_attachments" {
  description = "VPC attachment details for all cells"
  value       = module.vpc_attachments
}

output "attachment_ids" {
  description = "VPC attachment IDs for all cells"
  value       = { for k, v in module.vpc_attachments : k => v.attachment_id }
}

output "attachment_count" {
  description = "Number of VPC attachments created"
  value       = length(module.vpc_attachments)
}
