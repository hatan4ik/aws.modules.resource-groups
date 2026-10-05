mock_provider "aws" {}

variables {
  name = "payments-prod"

  membership = {
    resource_query = {
      tag_filters = [{ key = "Application", values = ["payments"] }]
    }
  }
}

# Every variable validation and resource precondition has a failing case
# here; the passing case for each lives in defaults, resource_query, or
# configuration.

run "rejects_name_with_invalid_characters" {
  command = plan
  variables {
    name = "payments prod"
  }
  expect_failures = [var.name]
}

run "rejects_empty_name" {
  command = plan
  variables {
    name = ""
  }
  expect_failures = [var.name]
}

run "rejects_name_longer_than_300_characters" {
  command = plan
  variables {
    name = join("", [for i in range(301) : "a"])
  }
  expect_failures = [var.name]
}

run "rejects_name_with_reserved_aws_prefix" {
  command = plan
  variables {
    name = "aws-payments"
  }
  expect_failures = [var.name]
}

run "rejects_name_with_reserved_aws_prefix_in_any_case" {
  command = plan
  variables {
    name = "AwS_payments"
  }
  expect_failures = [var.name]
}

run "rejects_description_with_disallowed_punctuation" {
  command = plan
  variables {
    description = "Payments, prod"
  }
  expect_failures = [var.description]
}

run "rejects_description_longer_than_1024_characters" {
  command = plan
  variables {
    description = join("", [for i in range(205) : "abcde"])
  }
  expect_failures = [var.description]
}

run "rejects_cloudformation_stack_query_type" {
  command = plan
  variables {
    membership = {
      resource_query = {
        type        = "CLOUDFORMATION_STACK_1_0"
        tag_filters = [{ key = "Application", values = ["payments"] }]
      }
    }
  }
  expect_failures = [var.membership]
}

run "rejects_unknown_query_type" {
  command = plan
  variables {
    membership = {
      resource_query = {
        type        = "TAG_FILTERS_2_0"
        tag_filters = [{ key = "Application", values = ["payments"] }]
      }
    }
  }
  expect_failures = [var.membership]
}

run "rejects_empty_tag_filters" {
  command = plan
  variables {
    membership = {
      resource_query = {
        tag_filters = []
      }
    }
  }
  expect_failures = [var.membership]
}

run "rejects_more_than_50_tag_filters" {
  command = plan
  variables {
    membership = {
      resource_query = {
        tag_filters = [for i in range(51) : { key = "key-${i}" }]
      }
    }
  }
  expect_failures = [var.membership]
}

run "rejects_empty_tag_filter_key" {
  command = plan
  variables {
    membership = {
      resource_query = {
        tag_filters = [{ key = "" }]
      }
    }
  }
  expect_failures = [var.membership]
}

run "rejects_tag_filter_key_with_invalid_character" {
  command = plan
  variables {
    membership = {
      resource_query = {
        tag_filters = [{ key = "team#1" }]
      }
    }
  }
  expect_failures = [var.membership]
}

run "rejects_tag_filter_key_longer_than_128_characters" {
  command = plan
  variables {
    membership = {
      resource_query = {
        tag_filters = [{ key = join("", [for i in range(129) : "k"]) }]
      }
    }
  }
  expect_failures = [var.membership]
}

run "rejects_tag_filter_with_more_than_256_values" {
  command = plan
  variables {
    membership = {
      resource_query = {
        tag_filters = [{ key = "Stage", values = [for i in range(257) : "v${i}"] }]
      }
    }
  }
  expect_failures = [var.membership]
}

run "rejects_tag_filter_value_longer_than_256_characters" {
  command = plan
  variables {
    membership = {
      resource_query = {
        tag_filters = [{ key = "Stage", values = [join("", [for i in range(257) : "v"])] }]
      }
    }
  }
  expect_failures = [var.membership]
}

run "rejects_duplicate_tag_filter_keys" {
  command = plan
  variables {
    membership = {
      resource_query = {
        tag_filters = [{ key = "Stage", values = ["prod"] }, { key = "Stage", values = ["beta"] }]
      }
    }
  }
  expect_failures = [var.membership]
}

run "rejects_malformed_resource_type_filter" {
  command = plan
  variables {
    membership = {
      resource_query = {
        resource_type_filters = ["ec2:instance"]
        tag_filters           = [{ key = "Stage" }]
      }
    }
  }
  expect_failures = [var.membership]
}

run "rejects_all_supported_mixed_with_other_types" {
  command = plan
  variables {
    membership = {
      resource_query = {
        resource_type_filters = ["AWS::AllSupported", "AWS::EC2::Instance"]
        tag_filters           = [{ key = "Stage" }]
      }
    }
  }
  expect_failures = [var.membership]
}

run "rejects_duplicate_resource_type_filters" {
  command = plan
  variables {
    membership = {
      resource_query = {
        resource_type_filters = ["AWS::EC2::Instance", "AWS::EC2::Instance"]
        tag_filters           = [{ key = "Stage" }]
      }
    }
  }
  expect_failures = [var.membership]
}

run "rejects_empty_configuration" {
  command = plan
  variables {
    membership = {
      configuration = []
    }
  }
  expect_failures = [var.membership]
}

run "rejects_more_than_two_configuration_items" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::EC2::CapacityReservationPool" }, { type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::CapacityReservation"] } }, { type = "AWS::EC2::HostManagement", parameters = { "any-host-based-license-configuration" = ["true"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_duplicate_configuration_types" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::CapacityReservation"] } }, { type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::CapacityReservation"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_appregistry_configuration_type" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::AppRegistry::Application", parameters = { Name = ["app"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_cloudformation_stack_configuration_type" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::CloudFormation::Stack", parameters = { Name = ["app"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_network_firewall_configuration_type" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::NetworkFirewall::RuleGroup" }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_unknown_configuration_type" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::ResourceGroups::Custom" }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_unknown_generic_parameter" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::EC2::CapacityReservationPool" }, { type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::CapacityReservation"], "max-members" = ["10"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_generic_allowed_resource_types_with_two_values" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::Host", "AWS::EC2::CapacityReservation"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_generic_allowed_resource_type_outside_the_documented_set" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::Instance"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_generic_deletion_protection_in_lowercase" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::ResourceGroups::Generic", parameters = { "deletion-protection" = ["unless_empty"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_unknown_capacity_reservation_pool_parameter" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::EC2::CapacityReservationPool", parameters = { "tenancy" = ["default"] } }, { type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::CapacityReservation"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_reservation_type_without_instance_type" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::EC2::CapacityReservationPool", parameters = { "reservation-type" = ["capacity-block"] } }, { type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::CapacityReservation"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_instance_type_without_reservation_type" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::EC2::CapacityReservationPool", parameters = { "instance-type" = ["trn2u.48xlarge"] } }, { type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::CapacityReservation"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_unknown_reservation_type" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::EC2::CapacityReservationPool", parameters = { "reservation-type" = ["on-demand"], "instance-type" = ["trn2u.48xlarge"] } }, { type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::CapacityReservation"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_malformed_instance_type" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::EC2::CapacityReservationPool", parameters = { "reservation-type" = ["capacity-block"], "instance-type" = ["trn2u 48xlarge"] } }, { type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::CapacityReservation"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_multiple_instance_types" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::EC2::CapacityReservationPool", parameters = { "reservation-type" = ["capacity-block"], "instance-type" = ["trn2u.48xlarge", "p6e-gb200.36xlarge"] } }, { type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::CapacityReservation"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_unknown_host_management_parameter" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::EC2::HostManagement", parameters = { "any-host-based-license-configuration" = ["true"], "host-recovery" = ["on"] } }, { type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::Host"], "deletion-protection" = ["UNLESS_EMPTY"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_host_management_boolean_in_uppercase" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::EC2::HostManagement", parameters = { "any-host-based-license-configuration" = ["true"], "auto-release-host" = ["True"] } }, { type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::Host"], "deletion-protection" = ["UNLESS_EMPTY"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_host_management_boolean_with_two_values" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::EC2::HostManagement", parameters = { "any-host-based-license-configuration" = ["true", "false"] } }, { type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::Host"], "deletion-protection" = ["UNLESS_EMPTY"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_both_host_license_parameters" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::EC2::HostManagement", parameters = { "any-host-based-license-configuration" = ["true"], "allowed-host-based-license-configurations" = ["arn:aws:license-manager:us-west-2:123456789012:license-configuration:lic-0123456789abcdef"] } }, { type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::Host"], "deletion-protection" = ["UNLESS_EMPTY"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_neither_host_license_parameter" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::EC2::HostManagement", parameters = { "auto-allocate-host" = ["true"] } }, { type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::Host"], "deletion-protection" = ["UNLESS_EMPTY"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_malformed_license_configuration_arn" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::EC2::HostManagement", parameters = { "allowed-host-based-license-configurations" = ["lic-0123456789abcdef"] } }, { type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::Host"], "deletion-protection" = ["UNLESS_EMPTY"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_empty_license_configuration_list" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::EC2::HostManagement", parameters = { "allowed-host-based-license-configurations" = [] } }, { type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::Host"], "deletion-protection" = ["UNLESS_EMPTY"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_malformed_host_family" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::EC2::HostManagement", parameters = { "any-host-based-license-configuration" = ["true"], "allowed-host-families" = ["c5.large"] } }, { type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::Host"], "deletion-protection" = ["UNLESS_EMPTY"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_empty_host_family_list" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::EC2::HostManagement", parameters = { "any-host-based-license-configuration" = ["true"], "allowed-host-families" = [] } }, { type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::Host"], "deletion-protection" = ["UNLESS_EMPTY"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_host_management_without_a_generic_item" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::EC2::HostManagement", parameters = { "any-host-based-license-configuration" = ["true"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_host_management_without_deletion_protection" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::EC2::HostManagement", parameters = { "any-host-based-license-configuration" = ["true"] } }, { type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::Host"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_host_management_paired_with_capacity_reservations" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::EC2::HostManagement", parameters = { "any-host-based-license-configuration" = ["true"] } }, { type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::CapacityReservation"], "deletion-protection" = ["UNLESS_EMPTY"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_capacity_reservation_pool_without_a_generic_item" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::EC2::CapacityReservationPool" }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_capacity_reservation_pool_paired_with_hosts" {
  command = plan
  variables {
    membership = {
      configuration = [{ type = "AWS::EC2::CapacityReservationPool" }, { type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::Host"] } }]
    }
  }
  expect_failures = [var.membership]
}

run "rejects_tag_key_with_reserved_aws_prefix" {
  command = plan
  variables {
    tags = { "aws:owner" = "platform" }
  }
  expect_failures = [var.tags]
}

run "rejects_tag_key_with_invalid_character" {
  command = plan
  variables {
    tags = { "owner#1" = "platform" }
  }
  expect_failures = [var.tags]
}

run "rejects_tag_value_longer_than_256_characters" {
  command = plan
  variables {
    tags = { Owner = join("", [for i in range(257) : "v"]) }
  }
  expect_failures = [var.tags]
}

run "rejects_both_resource_query_and_configuration" {
  command = plan
  variables {
    membership = {
      resource_query = { tag_filters = [{ key = "Stage" }] }
      configuration  = [{ type = "AWS::EC2::CapacityReservationPool" }, { type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::CapacityReservation"] } }]
    }
  }
  expect_failures = [aws_resourcegroups_group.this]
}

run "rejects_neither_resource_query_nor_configuration" {
  command = plan
  variables {
    membership = {}
  }
  expect_failures = [aws_resourcegroups_group.this]
}

run "rejects_a_rendered_query_longer_than_4096_characters" {
  command = plan
  variables {
    membership = {
      resource_query = {
        tag_filters = [for i in range(20) : { key = "key-${i}", values = [for j in range(10) : "a-fairly-long-value-${j}"] }]
      }
    }
  }
  expect_failures = [aws_resourcegroups_group.this]
}

run "rejects_more_than_50_tags_including_the_name_tag" {
  command = plan
  variables {
    tags = { for i in range(50) : "key-${i}" => "value" }
  }
  expect_failures = [aws_resourcegroups_group.this]
}
