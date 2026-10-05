output "group_arn" {
  description = "ARN of the resource group."
  value       = module.resource_group.arn
}

output "query" {
  description = "The exact resource query JSON the module sent to AWS."
  value       = module.resource_group.resource_query.query
}
