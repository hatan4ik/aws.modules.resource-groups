output "group_arn" {
  description = "ARN of the capacity reservation group; use it as capacity_reservation_target.capacity_reservation_resource_group_arn on an instance or launch template."
  value       = module.resource_group.arn
}

output "configuration" {
  description = "The group's normalized service configuration."
  value       = module.resource_group.configuration
}
