locals {
  # Which membership path the caller chose. The first validation on
  # var.membership guarantees exactly one is set.
  has_resource_query = var.membership.resource_query != null
  has_configuration  = !local.has_resource_query
  membership_mode    = local.has_resource_query ? "resource_query" : "configuration"

  # The query path's input, or empty lists on the configuration path so the
  # query locals below need no null checks of their own.
  query = local.has_resource_query ? var.membership.resource_query : {
    type                  = null
    tag_filters           = []
    resource_type_filters = []
  }

  # Canonical forms: sorted and de-duplicated, so reordering an input never
  # changes the rendered query and never produces a diff. An empty
  # resource_type_filters means every supported type, which AWS spells
  # AWS::AllSupported.
  resource_type_filters = length(local.query.resource_type_filters) == 0 ? ["AWS::AllSupported"] : sort(distinct(local.query.resource_type_filters))

  tag_filters = [
    for key in sort([for filter in local.query.tag_filters : filter.key]) : {
      key    = key
      values = sort(distinct(flatten([for filter in local.query.tag_filters : filter.values if filter.key == key])))
    }
  ]

  # The exact Query string AWS expects. jsonencode orders object keys
  # lexically (ResourceTypeFilters, TagFilters; Key, Values), which is also the
  # order of AWS's own examples. A key-only tag filter omits Values, the
  # Tagging API's spelling of "this key with any value".
  query_json = jsonencode({
    ResourceTypeFilters = local.resource_type_filters
    TagFilters = [
      for filter in local.tag_filters : merge(
        { Key = filter.key },
        { for name, values in { Values = filter.values } : name => values if length(values) > 0 },
      )
    ]
  })

  # Service configuration items in a stable order, each parameter's values as
  # given (their order can be significant to the owning service).
  configuration = local.has_configuration ? [
    for type in sort([for item in var.membership.configuration : item.type]) : one([
      for item in var.membership.configuration : { type = item.type, parameters = item.parameters } if item.type == type
    ])
  ] : []

  # The caller's Name tag wins; the module only fills the gap.
  tags = merge({ Name = var.name }, var.tags)
}
