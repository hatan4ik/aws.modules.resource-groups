# arn is computed by AWS and unknown under command = plan; asserting on it
# needs command = apply with a mocked resource. Kept in its own file: an apply
# run's state would otherwise leak into later plan-only runs sharing a file.

mock_provider "aws" {
  mock_resource "aws_resourcegroups_group" {
    defaults = {
      arn = "arn:aws:resource-groups:us-east-2:123456789012:group/payments-prod"
    }
  }
}

variables {
  name = "payments-prod"

  membership = {
    resource_query = {
      tag_filters = [{ key = "Application", values = ["payments"] }]
    }
  }
}

run "outputs_reflect_the_created_group" {
  command = apply

  assert {
    condition     = output.arn == "arn:aws:resource-groups:us-east-2:123456789012:group/payments-prod"
    error_message = "arn must equal the group's ARN."
  }

  assert {
    condition     = output.name == "payments-prod" && output.membership_mode == "resource_query"
    error_message = "name and membership_mode must reflect the created group."
  }

  assert {
    condition     = output.resource_query.query == "{\"ResourceTypeFilters\":[\"AWS::AllSupported\"],\"TagFilters\":[{\"Key\":\"Application\",\"Values\":[\"payments\"]}]}" && output.configuration == null
    error_message = "resource_query must survive apply unchanged and configuration must stay null."
  }
}
