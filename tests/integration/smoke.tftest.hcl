# Integration suite: real apply in the caller's own account.
#
# Requires AWS credentials and a region from the environment (for example
# AWS_PROFILE and AWS_REGION, or the OIDC role assumed by the integration
# workflow). Creates one tag-query resource group with a name suffixed by a
# hash of the current time (avoiding a hashicorp/random dependency, which
# would graft itself into the root's committed provider lock file), asserts
# what the real API reports, and destroys it at the end of the file. Resource
# groups are free and have no retention period; nothing lingers or costs
# anything. The query matches a tag key no real resource carries, so the
# group is empty and touches nothing else.
#
# Run: terraform init -backend=false -test-directory=tests/integration
#      terraform test -test-directory=tests/integration -filter=tests/integration/smoke.tftest.hcl

provider "aws" {}

run "smoke" {
  variables {
    name        = "rg-smoke-${substr(md5(timestamp()), 0, 10)}"
    description = "aws.modules.resource-groups smoke test"

    membership = {
      resource_query = {
        tag_filters = [
          { key = "IntegrationTest", values = ["aws.modules.resource-groups"] },
          { key = "Disposable" },
        ]
        resource_type_filters = ["AWS::EC2::Instance", "AWS::S3::Bucket"]
      }
    }

    tags = {
      IntegrationTest = "aws.modules.resource-groups"
      Disposable      = "true"
    }
  }

  assert {
    condition     = startswith(output.arn, "arn:") && strcontains(output.arn, ":group/${var.name}")
    error_message = "The group must be created with a real ARN naming it."
  }

  assert {
    condition     = output.name == var.name
    error_message = "name must equal the requested name."
  }

  assert {
    condition     = aws_resourcegroups_group.this.resource_query[0].type == "TAG_FILTERS_1_0" && jsondecode(aws_resourcegroups_group.this.resource_query[0].query) == jsondecode(output.resource_query.query)
    error_message = "The real API must store the rendered query, including a key-only filter, unchanged in meaning."
  }

  assert {
    condition     = aws_resourcegroups_group.this.tags["IntegrationTest"] == "aws.modules.resource-groups" && aws_resourcegroups_group.this.tags["Name"] == var.name
    error_message = "Tags, including the derived Name tag, must be applied to the real resource."
  }
}
