# CloudFormation stack group

Groups every resource that one CloudFormation stack created, for example a
vendor-supplied stack or a Service Catalog product deployed alongside a
Terraform-managed estate, so it shows up as one unit in the Resource Groups
console and in Systems Manager Application Manager.

AWS Resource Groups has a dedicated `CLOUDFORMATION_STACK_1_0` query type for
this, but the `hashicorp/aws` provider's `aws_resourcegroups_group` accepts
only `TAG_FILTERS_1_0`
([hashicorp/terraform-provider-aws#28690](https://github.com/hashicorp/terraform-provider-aws/issues/28690)),
so the module rejects the native type at plan time. This example uses the
equivalent that works today: CloudFormation tags every taggable resource it
creates with `aws:cloudformation:stack-id` set to the stack's ARN, and a tag
query on that key groups them.

The one difference from the native type: a stack query also lists stack
resources that cannot carry tags, which a tag query cannot see. Use the stack
ARN rather than `aws:cloudformation:stack-name`: a name is reused by the next
stack of the same name, an ARN never is.

## Run

```sh
terraform init
terraform plan \
  -var stack_name=payments \
  -var stack_arn=arn:aws:cloudformation:us-east-1:123456789012:stack/payments/11111111-2222-3333-4444-555555555555
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_resource_group"></a> [resource\_group](#module\_resource\_group) | ../../ | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | Name of the resource group. | `string` | `"payments-stack"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region of the CloudFormation stack. The group is created in the same region. | `string` | `"us-east-1"` | no |
| <a name="input_stack_arn"></a> [stack\_arn](#input\_stack\_arn) | Full ARN of the CloudFormation stack whose resources form the group (aws cloudformation describe-stacks --stack-name <name> --query 'Stacks[0].StackId'). | `string` | `"arn:aws:cloudformation:us-east-1:123456789012:stack/payments/11111111-2222-3333-4444-555555555555"` | no |
| <a name="input_stack_name"></a> [stack\_name](#input\_stack\_name) | Name of the CloudFormation stack, used only in the group's description. | `string` | `"payments"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_group_arn"></a> [group\_arn](#output\_group\_arn) | ARN of the resource group. |
| <a name="output_query"></a> [query](#output\_query) | The exact resource query JSON the module sent to AWS. |
<!-- END_TF_DOCS -->
