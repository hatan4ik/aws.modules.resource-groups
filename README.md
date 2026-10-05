# aws.modules.resource-groups

Creates one AWS Resource Group per module call: a named, taggable, regional
collection of AWS resources whose membership is defined either by a tag query
or by a service configuration, never both. The query is built from typed tag
filters and rendered to the exact JSON AWS expects; the service configuration
is validated against the documented AWS parameter rules before anything
reaches the API. It creates nothing else and performs no data-source reads.
Requires Terraform >= 1.7 and the AWS provider >= 6.35, < 7.

## Why this module

Terraform knows which resources belong together; AWS does not. A resource
group is the AWS-native, named answer to "everything that is payments-prod",
read directly by the Resource Groups console and Tag Editor, Systems Manager
Application Manager (every tag-query group becomes a custom application with
its alarms, OpsItems, compliance, and cost in one page), Systems Manager
targeting (`resource-groups:Name` targets, Maintenance Window
`RESOURCE_GROUP` targets), and EC2 and License Manager (capacity reservation
pools, dedicated host groups). See [docs/DESIGN.md](docs/DESIGN.md#why-a-terraform-managed-estate-wants-resource-groups-at-all).

What you get:

- One required `membership` object with two mutually exclusive attributes,
  `resource_query` and `configuration`. The call site names the path it
  chose; a variable validation rejects both or neither at plan time.
- No hand-written JSON. `tag_filters` is a list of `{ key, values }`; the
  module renders the query canonically (sorted, de-duplicated,
  `AWS::AllSupported` when no resource types are given, `Values` omitted for
  a key-only filter), so reordering inputs is never a diff. The rendered
  string is an output.
- Plan-time validation of every documented constraint: name and description
  character sets and lengths, the reserved `AWS` name prefix, tag filter
  counts and lengths, resource-type syntax, configuration types and each
  type's parameters, the pairing rules AWS imposes between configuration
  items, the 4,096-character query limit, and the 50-tag limit.
- Caller tags always win: the module adds `Name = name` only when you do not
  set a `Name` tag.
- Normalised `resource_query` and `configuration` outputs, known at plan time,
  for callers that compose further.

## Quick start

```hcl
module "payments_group" {
  source = "git::https://github.com/hatan4ik/aws.modules.resource-groups.git?ref=<commit-sha>" # v1.0.0

  name = "payments-prod"

  membership = {
    resource_query = {
      tag_filters = [
        { key = "Application", values = ["payments"] },
        { key = "Environment", values = ["prod"] },
      ]
    }
  }

  tags = { Owner = "platform" }
}
```

This creates a group whose members are every resource in the region tagged
`Application = payments` **and** `Environment = prod`, of any supported type.

## Membership

### `resource_query`: a tag query

| Field | Meaning |
| --- | --- |
| `type` | `TAG_FILTERS_1_0` (the default, and the only type the AWS provider accepts; see below). |
| `tag_filters` | 1 to 50 `{ key, values }` entries with distinct keys. A resource must carry every key (AND), with one of that key's values (OR). Omit `values` to match the key with any value. |
| `resource_type_filters` | Resource types such as `AWS::EC2::Instance`. Empty (the default) means `AWS::AllSupported`. |

The rendered query for the quick start:

```json
{"ResourceTypeFilters":["AWS::AllSupported"],"TagFilters":[{"Key":"Application","Values":["payments"]},{"Key":"Environment","Values":["prod"]}]}
```

#### CloudFormation stack groups

The Resource Groups API also defines a `CLOUDFORMATION_STACK_1_0` query type,
but `aws_resourcegroups_group` in the `hashicorp/aws` provider rejects it
([hashicorp/terraform-provider-aws#28690](https://github.com/hashicorp/terraform-provider-aws/issues/28690)),
so the module rejects it at plan time with a pointer to the equivalent: a tag
filter on `aws:cloudformation:stack-id` with the stack's ARN, which
CloudFormation sets on every taggable resource it creates. Untaggable stack
resources are not members of such a group. See
[examples/cloudformation-stack](examples/cloudformation-stack).

### `configuration`: a service-linked group

1 or 2 items of `{ type, parameters }`, distinct types. Members are added by
the owning service, not by a query.

| Type | Accepted `parameters` |
| --- | --- |
| `AWS::ResourceGroups::Generic` | `allowed-resource-types`: one of `AWS::EC2::Host`, `AWS::EC2::CapacityReservation`. `deletion-protection`: `UNLESS_EMPTY`. |
| `AWS::EC2::CapacityReservationPool` | none; or `reservation-type = ["capacity-block"]` with one `instance-type` (UltraServer Capacity Blocks). Requires a Generic item allowing `AWS::EC2::CapacityReservation`. |
| `AWS::EC2::HostManagement` | `auto-allocate-host`, `auto-release-host`, `any-host-based-license-configuration` (`"true"`/`"false"`), `allowed-host-families`, `allowed-host-based-license-configurations` (License Manager configuration ARNs); exactly one of the two license parameters. Requires a Generic item allowing `AWS::EC2::Host` with `deletion-protection = UNLESS_EMPTY`. |

`AWS::AppRegistry::Application` and `AWS::CloudFormation::Stack` groups are
created only by AppRegistry, and `AWS::NetworkFirewall::RuleGroup` needs a
query and a configuration together; all three are rejected with a message
saying so. A Generic-only configuration is accepted but raises the advisory
check `generic_only_configuration`, because such a group can never gain
members.

```hcl
membership = {
  configuration = [
    { type = "AWS::EC2::CapacityReservationPool" },
    {
      type       = "AWS::ResourceGroups::Generic"
      parameters = { "allowed-resource-types" = ["AWS::EC2::CapacityReservation"] }
    },
  ]
}
```

## Examples

- [tag-filters](examples/tag-filters): an application and environment group with a key-only filter.
- [cloudformation-stack](examples/cloudformation-stack): every taggable resource of one CloudFormation stack.
- [capacity-reservation-pool](examples/capacity-reservation-pool): a service-linked EC2 capacity reservation group.

## Architecture

```text
root (one resource group)
├── main.tf        aws_resourcegroups_group.this, the query-length / tag-count preconditions
├── locals.tf      membership mode, canonical tag filters and resource types, rendered query JSON
├── variables.tf   name, description, membership, tags, with every validation
├── checks.tf      generic_only_configuration (advisory)
└── outputs.tf     arn, name, membership_mode, resource_query, configuration, tags
```

## Lifecycle notes

- `name` cannot change in place; a new name replaces the group and its ARN.
- The provider cannot convert a query group into a configuration group or
  back. Change `name` at the same time so the group is replaced.
- A `HostManagement` group cannot be deleted while it has members
  (`deletion-protection = UNLESS_EMPTY` is mandatory for that type).
- Default quota: 100 groups per account per region (adjustable).

The full failure-mode table and quota list are in [docs/DESIGN.md](docs/DESIGN.md).

## Testing

- **Contract tests** (`tests/`, `make test` and CI) use `mock_provider`; no
  credentials. Both membership paths, the exact rendered query, every
  validation and precondition (`tests/validation.tftest.hcl`), the advisory
  check, and every output are covered. `arn` is asserted under
  `command = apply` in `tests/outputs_apply.tftest.hcl`.
- **Integration suite** (`tests/integration/`, `make integration-smoke` or the
  dispatch-only `integration` workflow) creates one real tag-query group in
  **your** account and destroys it. See
  [tests/integration/README.md](tests/integration/README.md).

## Compatibility and scope

- Terraform `>= 1.7.0, < 2.0.0`. AWS provider `>= 6.35.0, < 7.0.0`.
- Not here: tagging member resources, adding members to service-linked
  groups, native CloudFormation stack queries, Network Firewall rule-group
  groups. See [docs/DESIGN.md](docs/DESIGN.md#deferred-to-v2).

## Versioning and releases

Releases follow semantic versioning: incompatible interface changes bump the
major version, new optional inputs and outputs bump the minor version, fixes
bump the patch version. Every release is a signed annotated tag `vX.Y.Z`.

Pin the full commit SHA of the release tag and record the tag in a comment,
so the source cannot move under you:

```hcl
module "resource_group" {
  source = "git::https://github.com/hatan4ik/aws.modules.resource-groups.git?ref=<commit-sha>" # v1.0.0
}
```

The `module-release` workflow publishes an immutable GitHub release only
from a GitHub-verified, signed, annotated semantic-version tag that points
at the merged `main` revision; lightweight or unsigned tags are rejected
before anything is published. With a GitHub-associated GPG or SSH signing
key configured:

```bash
git fetch origin
git tag -s vX.Y.Z <commit> -m "vX.Y.Z"
git push origin vX.Y.Z
gh workflow run module-release.yml --ref vX.Y.Z -f release_tag=vX.Y.Z
```

Dispatch from the tag, never from `main`: the workflow verifies that the tag
points at the revision it checked out.

All changes are listed in [CHANGELOG.md](CHANGELOG.md).

## Contributing

Development setup, the local quality gate, the test-first workflow, and the
release process are described in [CONTRIBUTING.md](CONTRIBUTING.md).
Security reports go through [SECURITY.md](SECURITY.md).

## License

Apache-2.0. See [LICENSE](LICENSE).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.35.0, < 7.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_resourcegroups_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/resourcegroups_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_description"></a> [description](#input\_description) | Description of the resource group: at most 1,024 letters, digits, whitespace, hyphens, periods, and underscores. Null means the group has no description. | `string` | `null` | no |
| <a name="input_membership"></a> [membership](#input\_membership) | How the group's members are defined. Set exactly one of the two attributes; AWS accepts a group with either a resource query or a service configuration, never both, and the module rejects neither at plan time.<br/><br/>resource\_query: membership computed continuously from a tag query (TAG\_FILTERS\_1\_0).<br/>  type: TAG\_FILTERS\_1\_0, the default and the only query type the AWS provider accepts (CLOUDFORMATION\_STACK\_1\_0 is rejected by hashicorp/aws; see docs/DESIGN.md for the tag-based equivalent of a stack group).<br/>  tag\_filters: 1 to 50 entries with distinct keys. A resource must carry every key, and for a key with values, one of those values (keys AND, values OR). Empty values means the key with any value. Rendered sorted, so reordering is not a diff.<br/>  resource\_type\_filters: resource types such as AWS::EC2::Instance that restrict the query. Empty means AWS::AllSupported.<br/><br/>configuration: a service configuration (a service-linked group), 1 or 2 items with distinct types, whose members are added explicitly by the owning service (EC2 or License Manager), not by a query.<br/>  type: AWS::ResourceGroups::Generic, AWS::EC2::CapacityReservationPool, or AWS::EC2::HostManagement.<br/>  parameters: parameter name to its values. Generic accepts allowed-resource-types (one of AWS::EC2::Host or AWS::EC2::CapacityReservation) and deletion-protection (UNLESS\_EMPTY). CapacityReservationPool accepts reservation-type (capacity-block) and instance-type together, for UltraServer Capacity Blocks, or nothing. HostManagement accepts auto-allocate-host, auto-release-host, and any-host-based-license-configuration ("true" or "false"), allowed-host-families, and allowed-host-based-license-configurations (License Manager configuration ARNs); exactly one of the two license parameters is required.<br/>  AWS requires CapacityReservationPool to be paired with a Generic item allowing AWS::EC2::CapacityReservation, and HostManagement with a Generic item allowing AWS::EC2::Host and setting deletion-protection. | <pre>object({<br/>    resource_query = optional(object({<br/>      type = optional(string, "TAG_FILTERS_1_0")<br/>      tag_filters = list(object({<br/>        key    = string<br/>        values = optional(list(string), [])<br/>      }))<br/>      resource_type_filters = optional(list(string), [])<br/>    }))<br/>    configuration = optional(list(object({<br/>      type       = string<br/>      parameters = optional(map(list(string)), {})<br/>    })))<br/>  })</pre> | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource group: 1 to 300 letters, digits, hyphens, periods, and underscores, unique within the account and region. It cannot start with AWS in any capitalisation (reserved by AWS). AWS cannot rename a group, so changing it replaces the group. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the group itself (not to its members). The module adds Name = name only when you do not set a Name tag yourself; a caller tag always wins. At most 50 tags in total, including that Name tag. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the resource group, for example as the capacity reservation target of an EC2 launch, or in an IAM policy. |
| <a name="output_configuration"></a> [configuration](#output\_configuration) | The group's service configuration in normalized form, or null for a query group: a list of { type, parameters } sorted by type, where parameters maps each parameter name to its values. Known at plan time. |
| <a name="output_membership_mode"></a> [membership\_mode](#output\_membership\_mode) | Which membership path the group uses: resource\_query or configuration. Known at plan time. |
| <a name="output_name"></a> [name](#output\_name) | Name of the resource group, the identifier the Resource Groups API, the AWS CLI, and Systems Manager Application Manager use for it. |
| <a name="output_resource_query"></a> [resource\_query](#output\_resource\_query) | The group's resource query in normalized form, or null for a configuration group: type, query (the exact JSON string sent to AWS), tag\_filters (sorted by key, values sorted and de-duplicated), and resource\_type\_filters (sorted; ["AWS::AllSupported"] when none were given). Known at plan time. |
| <a name="output_tags"></a> [tags](#output\_tags) | Tags applied to the group, including the module's Name tag unless the caller set one. Excludes provider default\_tags. |
<!-- END_TF_DOCS -->
