provider "aws" {
  region = var.region
}

# The Resource Groups API has a native CLOUDFORMATION_STACK_1_0 query type, but
# the hashicorp/aws provider accepts only TAG_FILTERS_1_0. CloudFormation tags
# every resource it creates that supports tags with the AWS-reserved
# aws:cloudformation:stack-id tag, so a tag query on that key and the stack's
# ARN groups the same resources (see README for the one difference).
module "resource_group" {
  source = "../../"

  name        = var.name
  description = "Resources created by the CloudFormation stack ${var.stack_name}"

  membership = {
    resource_query = {
      tag_filters = [
        { key = "aws:cloudformation:stack-id", values = [var.stack_arn] },
      ]
    }
  }
}
