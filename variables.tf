# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

variable "name" {
  description = "Name of the resource group: 1 to 300 letters, digits, hyphens, periods, and underscores, unique within the account and region. It cannot start with AWS in any capitalisation (reserved by AWS). AWS cannot rename a group, so changing it replaces the group."
  type        = string
  nullable    = false

  validation {
    condition     = length(var.name) >= 1 && length(var.name) <= 300 && can(regex("^[a-zA-Z0-9_.-]+$", var.name))
    error_message = "name must be 1 to 300 characters of letters, digits, hyphens (-), periods (.), and underscores (_)."
  }

  validation {
    condition     = !startswith(lower(var.name), "aws")
    error_message = "name must not start with AWS in any capitalisation; AWS reserves that prefix for groups it creates itself (for example AWS_AppRegistry_Application-*)."
  }
}

variable "description" {
  description = "Description of the resource group: at most 1,024 letters, digits, whitespace, hyphens, periods, and underscores. Null means the group has no description."
  type        = string
  default     = null

  validation {
    condition     = var.description == null ? true : (length(var.description) <= 1024 && can(regex("^[\\sa-zA-Z0-9_.-]*$", var.description)))
    error_message = "description must be at most 1024 characters of letters, digits, whitespace, hyphens (-), periods (.), and underscores (_). AWS rejects any other character, including commas, colons, and slashes."
  }
}

# ---------------------------------------------------------------------------
# Membership: exactly one of resource_query or configuration
# ---------------------------------------------------------------------------

variable "membership" {
  description = <<-EOT
    How the group's members are defined. Set exactly one of the two attributes; AWS accepts a group with either a resource query or a service configuration, never both, and the module rejects neither at plan time.

    resource_query: membership computed continuously from a tag query (TAG_FILTERS_1_0).
      type: TAG_FILTERS_1_0, the default and the only query type the AWS provider accepts (CLOUDFORMATION_STACK_1_0 is rejected by hashicorp/aws; see docs/DESIGN.md for the tag-based equivalent of a stack group).
      tag_filters: 1 to 50 entries with distinct keys. A resource must carry every key, and for a key with values, one of those values (keys AND, values OR). Empty values means the key with any value. Rendered sorted, so reordering is not a diff.
      resource_type_filters: resource types such as AWS::EC2::Instance that restrict the query. Empty means AWS::AllSupported.

    configuration: a service configuration (a service-linked group), 1 or 2 items with distinct types, whose members are added explicitly by the owning service (EC2 or License Manager), not by a query.
      type: AWS::ResourceGroups::Generic, AWS::EC2::CapacityReservationPool, or AWS::EC2::HostManagement.
      parameters: parameter name to its values. Generic accepts allowed-resource-types (one of AWS::EC2::Host or AWS::EC2::CapacityReservation) and deletion-protection (UNLESS_EMPTY). CapacityReservationPool accepts reservation-type (capacity-block) and instance-type together, for UltraServer Capacity Blocks, or nothing. HostManagement accepts auto-allocate-host, auto-release-host, and any-host-based-license-configuration ("true" or "false"), allowed-host-families, and allowed-host-based-license-configurations (License Manager configuration ARNs); exactly one of the two license parameters is required.
      AWS requires CapacityReservationPool to be paired with a Generic item allowing AWS::EC2::CapacityReservation, and HostManagement with a Generic item allowing AWS::EC2::Host and setting deletion-protection.
  EOT
  type = object({
    resource_query = optional(object({
      type = optional(string, "TAG_FILTERS_1_0")
      tag_filters = list(object({
        key    = string
        values = optional(list(string), [])
      }))
      resource_type_filters = optional(list(string), [])
    }))
    configuration = optional(list(object({
      type       = string
      parameters = optional(map(list(string)), {})
    })))
  })
  nullable = false

  # --- resource_query ------------------------------------------------------

  validation {
    condition     = var.membership.resource_query == null ? true : var.membership.resource_query.type == "TAG_FILTERS_1_0"
    error_message = "membership.resource_query.type must be TAG_FILTERS_1_0. AWS also defines CLOUDFORMATION_STACK_1_0, but the hashicorp/aws provider rejects it (aws_resourcegroups_group accepts only TAG_FILTERS_1_0); group a stack's resources with a tag filter on aws:cloudformation:stack-id instead, as examples/cloudformation-stack shows."
  }

  validation {
    condition     = var.membership.resource_query == null ? true : length(var.membership.resource_query.tag_filters) >= 1 && length(var.membership.resource_query.tag_filters) <= 50
    error_message = "membership.resource_query.tag_filters needs 1 to 50 entries."
  }

  validation {
    condition = var.membership.resource_query == null ? true : alltrue([
      for filter in var.membership.resource_query.tag_filters :
      length(filter.key) >= 1 && length(filter.key) <= 128 && can(regex("^[\\p{L}\\p{Z}\\p{N}_.:/=+\\-@]+$", filter.key)) &&
      length(filter.values) <= 256 && alltrue([for value in filter.values : length(value) <= 256])
    ])
    error_message = "Every tag_filters key must be 1 to 128 characters of letters, digits, spaces, and _ . : / = + - @, with at most 256 values of at most 256 characters each."
  }

  validation {
    condition     = var.membership.resource_query == null ? true : length(distinct([for filter in var.membership.resource_query.tag_filters : filter.key])) == length(var.membership.resource_query.tag_filters)
    error_message = "tag_filters keys must be distinct. List every accepted value of a key in that key's single entry; two entries for one key would both have to match."
  }

  validation {
    condition = var.membership.resource_query == null ? true : (
      alltrue([for type in var.membership.resource_query.resource_type_filters : type == "AWS::AllSupported" || can(regex("^AWS::[A-Za-z0-9]+::[A-Za-z0-9]+$", type))]) &&
      length(distinct(var.membership.resource_query.resource_type_filters)) == length(var.membership.resource_query.resource_type_filters) &&
      (contains(var.membership.resource_query.resource_type_filters, "AWS::AllSupported") ? length(var.membership.resource_query.resource_type_filters) == 1 : true)
    )
    error_message = "resource_type_filters must be distinct resource types of the form AWS::<Service>::<Type>, or AWS::AllSupported on its own (the same as leaving the list empty)."
  }

  # --- configuration -------------------------------------------------------

  validation {
    condition = var.membership.configuration == null ? true : (
      length(var.membership.configuration) >= 1 &&
      length(var.membership.configuration) <= 2 &&
      length(distinct([for item in var.membership.configuration : item.type])) == length(var.membership.configuration)
    )
    error_message = "membership.configuration must hold 1 or 2 items (the AWS maximum) with distinct types."
  }

  validation {
    condition = var.membership.configuration == null ? true : alltrue([
      for item in var.membership.configuration : contains(["AWS::ResourceGroups::Generic", "AWS::EC2::CapacityReservationPool", "AWS::EC2::HostManagement"], item.type)
    ])
    error_message = "Every membership.configuration type must be AWS::ResourceGroups::Generic, AWS::EC2::CapacityReservationPool, or AWS::EC2::HostManagement. AWS::AppRegistry::Application and AWS::CloudFormation::Stack groups are created only by AppRegistry; AWS::NetworkFirewall::RuleGroup needs a query and a configuration together, which this module does not support (see docs/DESIGN.md)."
  }

  validation {
    condition = var.membership.configuration == null ? true : alltrue([
      for item in var.membership.configuration : item.type != "AWS::ResourceGroups::Generic" ? true : (
        length(setsubtract(keys(item.parameters), ["allowed-resource-types", "deletion-protection"])) == 0 &&
        contains(["null", jsonencode(["AWS::EC2::Host"]), jsonencode(["AWS::EC2::CapacityReservation"])], jsonencode(lookup(item.parameters, "allowed-resource-types", null))) &&
        contains(["null", jsonencode(["UNLESS_EMPTY"])], jsonencode(lookup(item.parameters, "deletion-protection", null)))
      )
    ])
    error_message = "AWS::ResourceGroups::Generic accepts only allowed-resource-types, with exactly one value AWS::EC2::Host or AWS::EC2::CapacityReservation, and deletion-protection, with exactly the value UNLESS_EMPTY."
  }

  validation {
    condition = var.membership.configuration == null ? true : alltrue([
      for item in var.membership.configuration : item.type != "AWS::EC2::CapacityReservationPool" ? true : (
        length(setsubtract(keys(item.parameters), ["reservation-type", "instance-type"])) == 0 &&
        contains(keys(item.parameters), "reservation-type") == contains(keys(item.parameters), "instance-type") &&
        contains(["null", jsonencode(["capacity-block"])], jsonencode(lookup(item.parameters, "reservation-type", null))) &&
        (contains(keys(item.parameters), "instance-type") ? (length(item.parameters["instance-type"]) == 1 && can(regex("^[a-z0-9-]+\\.[a-z0-9]+$", join("", item.parameters["instance-type"])))) : true)
      )
    ])
    error_message = "AWS::EC2::CapacityReservationPool accepts no parameters, or reservation-type = [\"capacity-block\"] together with a single instance-type such as trn2u.48xlarge (UltraServer Capacity Blocks)."
  }

  validation {
    condition = var.membership.configuration == null ? true : alltrue([
      for item in var.membership.configuration : item.type != "AWS::EC2::HostManagement" ? true : (
        length(setsubtract(keys(item.parameters), ["auto-allocate-host", "auto-release-host", "allowed-host-families", "allowed-host-based-license-configurations", "any-host-based-license-configuration"])) == 0 &&
        alltrue([for flag in ["auto-allocate-host", "auto-release-host", "any-host-based-license-configuration"] : contains(["null", jsonencode(["true"]), jsonencode(["false"])], jsonencode(lookup(item.parameters, flag, null)))]) &&
        contains(keys(item.parameters), "allowed-host-based-license-configurations") != contains(keys(item.parameters), "any-host-based-license-configuration") &&
        alltrue([for arn in lookup(item.parameters, "allowed-host-based-license-configurations", []) : can(regex("^arn:aws[a-z-]*:license-manager:[a-z0-9-]+:[0-9]{12}:license-configuration:lic-[0-9a-fA-F]+$", arn))]) &&
        (contains(keys(item.parameters), "allowed-host-based-license-configurations") ? length(item.parameters["allowed-host-based-license-configurations"]) >= 1 : true) &&
        (contains(keys(item.parameters), "allowed-host-families") ? (length(item.parameters["allowed-host-families"]) >= 1 && alltrue([for family in item.parameters["allowed-host-families"] : can(regex("^[a-zA-Z0-9-]+$", family))])) : true)
      )
    ])
    error_message = "AWS::EC2::HostManagement accepts auto-allocate-host, auto-release-host, and any-host-based-license-configuration (each a single lowercase \"true\" or \"false\"), allowed-host-families (instance families such as c5), and allowed-host-based-license-configurations (License Manager configuration ARNs), with exactly one of the two license parameters set."
  }

  validation {
    condition = var.membership.configuration == null ? true : (
      !contains([for item in var.membership.configuration : item.type], "AWS::EC2::HostManagement") ? true : anytrue([
        for item in var.membership.configuration :
        item.type == "AWS::ResourceGroups::Generic" &&
        jsonencode(lookup(item.parameters, "allowed-resource-types", [])) == jsonencode(["AWS::EC2::Host"]) &&
        jsonencode(lookup(item.parameters, "deletion-protection", [])) == jsonencode(["UNLESS_EMPTY"])
      ])
    )
    error_message = "AWS requires an AWS::EC2::HostManagement configuration to be paired with an AWS::ResourceGroups::Generic item setting allowed-resource-types = [\"AWS::EC2::Host\"] and deletion-protection = [\"UNLESS_EMPTY\"]."
  }

  validation {
    condition = var.membership.configuration == null ? true : (
      !contains([for item in var.membership.configuration : item.type], "AWS::EC2::CapacityReservationPool") ? true : anytrue([
        for item in var.membership.configuration :
        item.type == "AWS::ResourceGroups::Generic" &&
        jsonencode(lookup(item.parameters, "allowed-resource-types", [])) == jsonencode(["AWS::EC2::CapacityReservation"])
      ])
    )
    error_message = "AWS requires an AWS::EC2::CapacityReservationPool configuration to be paired with an AWS::ResourceGroups::Generic item setting allowed-resource-types = [\"AWS::EC2::CapacityReservation\"]."
  }
}

# ---------------------------------------------------------------------------
# Tags
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Tags applied to the group itself (not to its members). The module adds Name = name only when you do not set a Name tag yourself; a caller tag always wins. At most 50 tags in total, including that Name tag."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([
      for key, value in var.tags :
      length(key) >= 1 && length(key) <= 128 && can(regex("^[\\p{L}\\p{Z}\\p{N}_.:/=+\\-@]+$", key)) && !startswith(lower(key), "aws:") &&
      length(value) <= 256 && can(regex("^[\\p{L}\\p{Z}\\p{N}_.:/=+\\-@]*$", value))
    ])
    error_message = "Tag keys must be 1 to 128 characters and values at most 256, both of letters, digits, spaces, and _ . : / = + - @; keys must not start with the reserved aws: prefix."
  }
}
