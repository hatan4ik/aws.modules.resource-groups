mock_provider "aws" {}

variables {
  name = "capacity-pool"

  membership = {
    configuration = [
      { type = "AWS::EC2::CapacityReservationPool" },
      {
        type       = "AWS::ResourceGroups::Generic"
        parameters = { "allowed-resource-types" = ["AWS::EC2::CapacityReservation"] }
      },
    ]
  }
}

run "renders_a_capacity_reservation_pool" {
  command = plan

  assert {
    condition     = length(aws_resourcegroups_group.this.configuration) == 2 && length(aws_resourcegroups_group.this.resource_query) == 0
    error_message = "A configuration membership must render one configuration block per item and no resource_query block."
  }

  assert {
    condition     = length([for item in aws_resourcegroups_group.this.configuration : item if item.type == "AWS::EC2::CapacityReservationPool" && length(item.parameters) == 0]) == 1
    error_message = "The pool item must render with no parameters."
  }

  assert {
    condition = length([
      for item in aws_resourcegroups_group.this.configuration : item
      if item.type == "AWS::ResourceGroups::Generic" && length(item.parameters) == 1 && alltrue([for p in item.parameters : p.name == "allowed-resource-types" && jsonencode(p.values) == jsonencode(["AWS::EC2::CapacityReservation"])])
    ]) == 1
    error_message = "The Generic item must render allowed-resource-types = [AWS::EC2::CapacityReservation]."
  }
}

run "exposes_every_output_for_a_configuration_group" {
  command = plan

  assert {
    condition     = output.name == "capacity-pool" && output.membership_mode == "configuration" && output.resource_query == null
    error_message = "A configuration group must expose its name, mode configuration, and a null resource_query."
  }

  assert {
    condition = jsonencode(output.configuration) == jsonencode([
      { type = "AWS::EC2::CapacityReservationPool", parameters = {} },
      { type = "AWS::ResourceGroups::Generic", parameters = { "allowed-resource-types" = ["AWS::EC2::CapacityReservation"] } },
    ])
    error_message = "configuration must echo every item sorted by type, with parameters as a map (empty when none were given)."
  }

  assert {
    condition     = output.tags["Name"] == "capacity-pool"
    error_message = "tags must include the derived Name tag."
  }
}

run "renders_an_ultraserver_capacity_block_pool" {
  command = plan

  variables {
    membership = {
      configuration = [
        {
          type = "AWS::EC2::CapacityReservationPool"
          parameters = {
            "reservation-type" = ["capacity-block"]
            "instance-type"    = ["trn2u.48xlarge"]
          }
        },
        {
          type       = "AWS::ResourceGroups::Generic"
          parameters = { "allowed-resource-types" = ["AWS::EC2::CapacityReservation"] }
        },
      ]
    }
  }

  assert {
    condition = length([
      for item in aws_resourcegroups_group.this.configuration : item
      if item.type == "AWS::EC2::CapacityReservationPool" && length(item.parameters) == 2
    ]) == 1
    error_message = "The pool item must render both Capacity Block parameters."
  }
}

run "renders_a_host_management_group" {
  command = plan

  variables {
    name = "dedicated-hosts"
    membership = {
      configuration = [
        {
          type = "AWS::EC2::HostManagement"
          parameters = {
            "auto-allocate-host"                        = ["true"]
            "auto-release-host"                         = ["false"]
            "allowed-host-families"                     = ["c5", "m5"]
            "allowed-host-based-license-configurations" = ["arn:aws:license-manager:us-west-2:123456789012:license-configuration:lic-6eb6586f508a786a2ba41e0123456789"]
          }
        },
        {
          type = "AWS::ResourceGroups::Generic"
          parameters = {
            "allowed-resource-types" = ["AWS::EC2::Host"]
            "deletion-protection"    = ["UNLESS_EMPTY"]
          }
        },
      ]
    }
  }

  assert {
    condition     = length([for item in aws_resourcegroups_group.this.configuration : item if item.type == "AWS::EC2::HostManagement" && length(item.parameters) == 4]) == 1
    error_message = "The HostManagement item must render all four declared parameters."
  }

  assert {
    condition     = length([for item in aws_resourcegroups_group.this.configuration : item if item.type == "AWS::ResourceGroups::Generic" && length(item.parameters) == 2]) == 1
    error_message = "The Generic item must render allowed-resource-types and deletion-protection."
  }
}

run "renders_a_host_management_group_with_any_license" {
  command = plan

  variables {
    membership = {
      configuration = [
        {
          type       = "AWS::EC2::HostManagement"
          parameters = { "any-host-based-license-configuration" = ["true"] }
        },
        {
          type = "AWS::ResourceGroups::Generic"
          parameters = {
            "allowed-resource-types" = ["AWS::EC2::Host"]
            "deletion-protection"    = ["UNLESS_EMPTY"]
          }
        },
      ]
    }
  }

  assert {
    condition     = output.membership_mode == "configuration" && length(output.configuration) == 2
    error_message = "A HostManagement group with any-host-based-license-configuration must be accepted."
  }
}

run "warns_when_only_a_generic_item_is_declared" {
  command = plan

  variables {
    membership = {
      configuration = [{
        type       = "AWS::ResourceGroups::Generic"
        parameters = { "deletion-protection" = ["UNLESS_EMPTY"] }
      }]
    }
  }

  assert {
    condition     = length(aws_resourcegroups_group.this.configuration) == 1
    error_message = "A Generic-only configuration is valid and must still render."
  }

  expect_failures = [check.generic_only_configuration]
}
