# One resource group whose membership is defined by exactly one of a resource
# query or a service configuration (locals.tf derives which). Variable
# validations check each path's shape; the preconditions below check what a
# single variable validation cannot: the choice between the two paths and the
# limits of the rendered request.

resource "aws_resourcegroups_group" "this" {
  name        = var.name
  description = var.description

  dynamic "resource_query" {
    for_each = local.has_resource_query ? [local.query_json] : []

    content {
      type  = local.query.type
      query = resource_query.value
    }
  }

  dynamic "configuration" {
    for_each = local.configuration

    content {
      type = configuration.value.type

      dynamic "parameters" {
        for_each = configuration.value.parameters

        content {
          name   = parameters.key
          values = parameters.value
        }
      }
    }
  }

  tags = local.tags

  lifecycle {
    precondition {
      condition     = local.has_resource_query != local.has_configuration
      error_message = "Set exactly one of membership.resource_query or membership.configuration. AWS accepts a group with a resource query or a service configuration, but not both, and a group with neither has no way to gain members."
    }

    precondition {
      condition     = !local.has_resource_query || length(local.query_json) <= 4096
      error_message = "The rendered resource query is ${length(local.query_json)} characters; AWS accepts at most 4096. Reduce the number of tag_filters values or resource_type_filters."
    }

    precondition {
      condition     = length(local.tags) <= 50
      error_message = "The group would carry ${length(local.tags)} tags, including the module's Name tag; AWS allows at most 50 per resource."
    }
  }
}
