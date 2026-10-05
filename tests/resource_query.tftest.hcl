mock_provider "aws" {}

variables {
  name = "query-group"

  membership = {
    resource_query = {
      type        = "TAG_FILTERS_1_0"
      tag_filters = [{ key = "Application", values = ["payments"] }]
    }
  }
}

run "renders_a_key_only_filter_without_values" {
  command = plan

  variables {
    membership = {
      resource_query = {
        type        = "TAG_FILTERS_1_0"
        tag_filters = [{ key = "CostCenter" }]
      }
    }
  }

  assert {
    condition     = aws_resourcegroups_group.this.resource_query[0].query == "{\"ResourceTypeFilters\":[\"AWS::AllSupported\"],\"TagFilters\":[{\"Key\":\"CostCenter\"}]}"
    error_message = "A tag filter with no values must omit Values, meaning the key with any value."
  }

  assert {
    condition     = length(output.resource_query.tag_filters[0].values) == 0
    error_message = "The normalized tag filter must report an empty values list."
  }
}

run "renders_tag_filters_and_values_in_canonical_order" {
  command = plan

  variables {
    membership = {
      resource_query = {
        type = "TAG_FILTERS_1_0"
        tag_filters = [
          { key = "Stage", values = ["prod", "beta", "prod"] },
          { key = "Application", values = ["payments"] },
          { key = "Owner" },
        ]
      }
    }
  }

  assert {
    condition     = aws_resourcegroups_group.this.resource_query[0].query == "{\"ResourceTypeFilters\":[\"AWS::AllSupported\"],\"TagFilters\":[{\"Key\":\"Application\",\"Values\":[\"payments\"]},{\"Key\":\"Owner\"},{\"Key\":\"Stage\",\"Values\":[\"beta\",\"prod\"]}]}"
    error_message = "Tag filters must be sorted by key and values sorted and de-duplicated, so reordering inputs never changes the query."
  }

  assert {
    condition     = jsonencode(output.resource_query.tag_filters) == jsonencode([{ key = "Application", values = ["payments"] }, { key = "Owner", values = [] }, { key = "Stage", values = ["beta", "prod"] }])
    error_message = "The resource_query output must echo the canonical tag filters."
  }
}

run "restricts_a_tag_query_to_declared_resource_types" {
  command = plan

  variables {
    membership = {
      resource_query = {
        type                  = "TAG_FILTERS_1_0"
        tag_filters           = [{ key = "Application", values = ["payments"] }]
        resource_type_filters = ["AWS::S3::Bucket", "AWS::EC2::Instance"]
      }
    }
  }

  assert {
    condition     = aws_resourcegroups_group.this.resource_query[0].query == "{\"ResourceTypeFilters\":[\"AWS::EC2::Instance\",\"AWS::S3::Bucket\"],\"TagFilters\":[{\"Key\":\"Application\",\"Values\":[\"payments\"]}]}"
    error_message = "Declared resource types must replace AWS::AllSupported, sorted."
  }
}

run "accepts_an_explicit_all_supported_filter" {
  command = plan

  variables {
    membership = {
      resource_query = {
        type                  = "TAG_FILTERS_1_0"
        tag_filters           = [{ key = "Application", values = ["payments"] }]
        resource_type_filters = ["AWS::AllSupported"]
      }
    }
  }

  assert {
    condition     = jsonencode(output.resource_query.resource_type_filters) == jsonencode(["AWS::AllSupported"])
    error_message = "AWS::AllSupported on its own must be accepted and equal the default."
  }
}

run "defaults_type_to_tag_filters" {
  command = plan

  variables {
    membership = {
      resource_query = {
        tag_filters = [{ key = "Application", values = ["payments"] }]
      }
    }
  }

  assert {
    condition     = aws_resourcegroups_group.this.resource_query[0].type == "TAG_FILTERS_1_0" && output.resource_query.type == "TAG_FILTERS_1_0"
    error_message = "An omitted query type must default to TAG_FILTERS_1_0."
  }
}

run "groups_a_cloudformation_stack_through_its_stack_id_tag" {
  command = plan

  variables {
    membership = {
      resource_query = {
        tag_filters = [{
          key    = "aws:cloudformation:stack-id"
          values = ["arn:aws:cloudformation:us-east-1:123456789012:stack/payments/11111111-2222-3333-4444-555555555555"]
        }]
      }
    }
  }

  assert {
    condition     = aws_resourcegroups_group.this.resource_query[0].query == "{\"ResourceTypeFilters\":[\"AWS::AllSupported\"],\"TagFilters\":[{\"Key\":\"aws:cloudformation:stack-id\",\"Values\":[\"arn:aws:cloudformation:us-east-1:123456789012:stack/payments/11111111-2222-3333-4444-555555555555\"]}]}"
    error_message = "A tag filter on the AWS-reserved aws:cloudformation:stack-id key must be accepted and rendered verbatim, since that is how a stack's resources are grouped with this provider."
  }
}
