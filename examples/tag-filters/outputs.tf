output "group_arn" {
  description = "ARN of the resource group."
  value       = module.resource_group.arn
}

output "group_name" {
  description = "Name of the resource group, as shown in the Resource Groups console and Systems Manager Application Manager."
  value       = module.resource_group.name
}

output "query" {
  description = "The exact resource query JSON the module sent to AWS."
  value       = module.resource_group.resource_query.query
}
