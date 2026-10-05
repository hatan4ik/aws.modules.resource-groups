mock_provider "aws" {}

variables {
  name = "payments-prod"

  membership = {
    resource_query = {
      type        = "TAG_FILTERS_1_0"
      tag_filters = [{ key = "Application", values = ["payments"] }]
    }
  }

  tags = { Environment = "prod", Owner = "platform" }
}

run "creates_one_tag_query_group_with_the_given_name" {
  command = plan

  assert {
    condition     = aws_resourcegroups_group.this.name == "payments-prod" && aws_resourcegroups_group.this.description == null
    error_message = "The group must carry the given name and no description unless one is declared."
  }

  assert {
    condition     = length(aws_resourcegroups_group.this.resource_query) == 1 && aws_resourcegroups_group.this.resource_query[0].type == "TAG_FILTERS_1_0"
    error_message = "A resource_query membership must render exactly one TAG_FILTERS_1_0 resource_query block."
  }

  assert {
    condition     = aws_resourcegroups_group.this.resource_query[0].query == "{\"ResourceTypeFilters\":[\"AWS::AllSupported\"],\"TagFilters\":[{\"Key\":\"Application\",\"Values\":[\"payments\"]}]}"
    error_message = "The query must be AWS's exact JSON, defaulting ResourceTypeFilters to AWS::AllSupported."
  }

  assert {
    condition     = length(aws_resourcegroups_group.this.configuration) == 0
    error_message = "A resource_query membership must render no configuration block."
  }

  assert {
    condition     = aws_resourcegroups_group.this.tags["Name"] == "payments-prod" && aws_resourcegroups_group.this.tags["Environment"] == "prod" && aws_resourcegroups_group.this.tags["Owner"] == "platform" && length(aws_resourcegroups_group.this.tags) == 3
    error_message = "Caller tags must be preserved and a Name tag derived from name."
  }
}

run "keeps_a_caller_supplied_name_tag" {
  command = plan

  variables {
    tags = { Name = "custom", Owner = "platform" }
  }

  assert {
    condition     = aws_resourcegroups_group.this.tags["Name"] == "custom" && aws_resourcegroups_group.this.tags["Owner"] == "platform" && length(aws_resourcegroups_group.this.tags) == 2
    error_message = "A caller Name tag must never be overridden by the module's default."
  }

  assert {
    condition     = output.tags["Name"] == "custom"
    error_message = "The tags output must reflect the caller's Name tag."
  }
}

run "renders_a_declared_description" {
  command = plan

  variables {
    description = "Every resource of the payments application in prod"
  }

  assert {
    condition     = aws_resourcegroups_group.this.description == "Every resource of the payments application in prod"
    error_message = "description must pass through unchanged."
  }
}

run "exposes_every_output_for_a_query_group" {
  command = plan

  assert {
    condition     = output.name == "payments-prod" && output.membership_mode == "resource_query" && output.configuration == null
    error_message = "A query group must expose its name, mode resource_query, and a null configuration."
  }

  assert {
    condition     = output.resource_query.type == "TAG_FILTERS_1_0" && output.resource_query.query == aws_resourcegroups_group.this.resource_query[0].query
    error_message = "resource_query must echo the type and the exact rendered query."
  }

  assert {
    condition     = jsonencode(output.resource_query.tag_filters) == jsonencode([{ key = "Application", values = ["payments"] }]) && jsonencode(output.resource_query.resource_type_filters) == jsonencode(["AWS::AllSupported"])
    error_message = "resource_query must echo the normalized tag_filters and resource_type_filters."
  }

  assert {
    condition     = jsonencode(output.tags) == jsonencode({ Environment = "prod", Name = "payments-prod", Owner = "platform" })
    error_message = "tags must expose the group's tags including the derived Name tag."
  }
}
