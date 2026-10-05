# Tag-filter group

The common case for `aws.modules.resource-groups`: one group whose members are
every resource in the region that carries a given set of tags. Here that is
every resource tagged `Application = payments` and `Environment = prod` that
also carries a `CostCenter` tag with any value. Keys are ANDed; the values
listed for one key are ORed; a key with no values matches any value.

The module renders the query JSON itself (sorted, so reordering the filters is
never a diff) and the `query` output shows exactly what AWS received. Set
`resource_types` to restrict the group to specific types, for example
`["AWS::EC2::Instance", "AWS::RDS::DBInstance"]`.

The group appears in the Resource Groups console, and in Systems Manager
Application Manager under Custom applications.

## Run

```sh
terraform init
terraform plan -var application=payments -var environment=prod
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
| <a name="input_application"></a> [application](#input\_application) | Value of the Application tag that the group's members carry, such as payments. | `string` | `"payments"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Value of the Environment tag that the group's members carry, such as prod. | `string` | `"prod"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region the resource group is created in. A group only ever contains resources from its own region. | `string` | `"us-east-1"` | no |
| <a name="input_resource_types"></a> [resource\_types](#input\_resource\_types) | Resource types to restrict the group to, such as AWS::EC2::Instance. Empty means every supported type. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_group_arn"></a> [group\_arn](#output\_group\_arn) | ARN of the resource group. |
| <a name="output_group_name"></a> [group\_name](#output\_group\_name) | Name of the resource group, as shown in the Resource Groups console and Systems Manager Application Manager. |
| <a name="output_query"></a> [query](#output\_query) | The exact resource query JSON the module sent to AWS. |
<!-- END_TF_DOCS -->
