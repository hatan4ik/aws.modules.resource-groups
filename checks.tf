# Advisory checks: they warn on every plan and apply but never block. Each
# describes a configuration that is valid yet usually unintended.

check "generic_only_configuration" {
  assert {
    condition     = !local.has_configuration ? true : length([for item in local.configuration : item if item.type != "AWS::ResourceGroups::Generic"]) > 0
    error_message = "membership.configuration holds only an AWS::ResourceGroups::Generic item. Such a group has no query and no owning service, and AWS's GroupResources operation adds members only to AWS::EC2::HostManagement and AWS::EC2::CapacityReservationPool groups, so it can never gain members. Pair it with one of those types, or use membership.resource_query."
  }
}
