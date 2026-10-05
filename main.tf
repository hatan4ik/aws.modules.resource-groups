# One resource group whose membership is defined by exactly one of a resource
# query or a service configuration. Variable validations on var.membership
# enforce that choice and each path's shape; the preconditions below check
# limits of the rendered request, which depend on locals (the canonical query
# string, and the module's Name tag merged into the caller's tags).

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
      condition     = !local.has_resource_query || length(local.query_json) <= 4096
      error_message = "The rendered resource query is ${length(local.query_json)} characters; AWS accepts at most 4096. Reduce the number of tag_filters values or resource_type_filters."
    }

    precondition {
      condition     = length(local.tags) <= 50
      error_message = "The group would carry ${length(local.tags)} tags, including the module's Name tag; AWS allows at most 50 per resource."
    }
  }
}
