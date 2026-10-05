output "arn" {
  description = "ARN of the resource group, for example to reference it from a Network Firewall rule, an EC2 launch targeting a capacity reservation group, or an IAM policy."
  value       = aws_resourcegroups_group.this.arn
}

output "name" {
  description = "Name of the resource group, the identifier the Resource Groups API, the AWS CLI, and Systems Manager Application Manager use for it."
  value       = aws_resourcegroups_group.this.name
}

output "membership_mode" {
  description = "Which membership path the group uses: resource_query or configuration. Known at plan time."
  value       = local.membership_mode
}

output "resource_query" {
  description = "The group's resource query in normalized form, or null for a configuration group: type, query (the exact JSON string sent to AWS), tag_filters (sorted by key, values sorted and de-duplicated), and resource_type_filters (sorted; [\"AWS::AllSupported\"] when none were given). Known at plan time."
  value = local.has_resource_query ? {
    type                  = local.query.type
    query                 = local.query_json
    tag_filters           = local.tag_filters
    resource_type_filters = local.resource_type_filters
  } : null
}

output "configuration" {
  description = "The group's service configuration in normalized form, or null for a query group: a list of { type, parameters } sorted by type, where parameters maps each parameter name to its values. Known at plan time."
  value       = local.has_configuration ? local.configuration : null
}

output "tags" {
  description = "Tags applied to the group, including the module's Name tag unless the caller set one. Excludes provider default_tags."
  value       = aws_resourcegroups_group.this.tags
}
