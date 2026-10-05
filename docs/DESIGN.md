# Design: aws.modules.resource-groups v1

Status: accepted 2026-10-05. Brand new module; no prior version, no
`docs/UPGRADE-1.0.md`.

## Purpose

`aws.modules.resource-groups` creates **one** AWS Resource Group
(`aws_resourcegroups_group`) per module call: a named, taggable, regional
collection of AWS resources whose membership is defined either by a tag query
or by a service configuration.

### Why a Terraform-managed estate wants resource groups at all

Terraform already knows which resources belong together: they share a state
file and a module tree. AWS does not. Everything outside Terraform that needs
"the resources of application X in environment Y" either reconstructs that
from tags on every call or reads it from a resource group. A resource group
is the AWS-native, named answer, and these consumers read it directly:

- **Console visibility.** The Resource Groups console lists a group's members
  across services in one view, and Tag Editor works on them in bulk. An
  operator who never opens the Terraform repository can still see "everything
  that is payments-prod".
- **Systems Manager Application Manager.** Every tag-query resource group in
  the region appears as a custom application in Application Manager, which
  aggregates the members' CloudWatch alarms, OpsItems, Config compliance,
  cost, and runbooks into one operational page. Creating the group is the
  only step needed to get that page.
- **Systems Manager targeting.** Run Command and State Manager associations
  accept the `resource-groups:Name` target key, and Maintenance Windows a
  `RESOURCE_GROUP` target, so fleet operations follow the group's membership
  instead of a hand-maintained instance list.
- **Cost views.** The members of a tag-query group are, by construction, the
  resources carrying the tags the group filters on; activating the same tag
  keys as cost allocation tags makes Cost Explorer's view of the application
  line up with the group's membership.
- **Tagging API and service integrations.** A group's ARN is accepted where
  AWS services want a set of resources: EC2 launches target a capacity
  reservation group's ARN, License Manager host resource groups are
  `AWS::EC2::HostManagement` groups, and `ListGroupResources` returns the
  current membership to any script or tool with the ARN.

### What it deliberately does not do

It does not tag the member resources (the caller's other modules do, and the
group follows those tags), does not add members to a service-linked group
(that is the owning service's `GroupResources` call), and does not create
the things a group is consumed by (Application Manager, SSM associations,
launch templates). It reads nothing: no data sources.

## Decisions

### ADR-1: one `membership` object with two mutually exclusive attributes

AWS accepts a group with a `ResourceQuery` or a `Configuration`, never both
(`CreateGroup`: "A resource group can contain either a Configuration or a
ResourceQuery, but not both"), and a group with neither has no way to gain
members. HCL has no sum types, so the choice is how close the interface can
get to one.

Two separate top-level variables (`resource_query`, `configuration`) were
rejected: each looks independently optional, and nothing at the call site
says that setting one forbids the other. Instead both live under one required
`membership` object:

```hcl
membership = { resource_query = { tag_filters = [...] } }
# or
membership = { configuration = [...] }
```

The call site names the path it chose, a reader sees both alternatives in one
type, and `membership` itself has no default, so "neither" cannot happen by
omission. What the type system still cannot express — exactly one attribute
non-null — is the first `validation` block on `var.membership`
(`variables.tf`). Both attributes live in that one variable, so a single
variable validation can compare them; it runs at plan, before anything reaches
AWS, and lets every other validation and every local assume exactly one path
is set. Within each path the type carries as much as it
can: `tag_filters` is a list of `{ key, values }` objects (never JSON), and
`configuration` items are `{ type, parameters = map(list(string)) }` matching
the API's own `GroupConfigurationItem` shape.

### ADR-2: the module renders the query JSON

AWS's `ResourceQuery.Query` is a JSON string inside a JSON request. A caller
hand-writing it gets escaping, key spelling (`ResourceTypeFilters`,
`TagFilters`, `Key`, `Values`), and the `AWS::AllSupported` sentinel wrong in
ways AWS reports only at apply. The module builds it with `jsonencode` from
the typed input and exposes the result as `resource_query.query`, so a caller
can still see exactly what was sent.

The rendering is canonical: filters sorted by key, values sorted and
de-duplicated, resource types sorted, an empty `resource_type_filters`
rendered as `["AWS::AllSupported"]`, and a key-only filter rendered without
`Values` (the Tagging API's "this key with any value"). Reordering inputs
therefore never produces a diff. `jsonencode` orders object keys lexically,
which coincides with the order in AWS's own examples.

Distinct tag-filter keys are required. Two entries for one key are legal JSON
but mean "the resource matches both", which for a single-valued tag is almost
always a mistake for "either value"; listing every value in one entry is the
correct and unambiguous spelling.

### ADR-3: `CLOUDFORMATION_STACK_1_0` is rejected, with a tag-based equivalent

The Resource Groups API defines a second query type, `CLOUDFORMATION_STACK_1_0`
(`{"ResourceTypeFilters":[...],"StackIdentifier":"<stack ARN>"}`). The
`hashicorp/aws` provider rejects it: `aws_resourcegroups_group`'s
`resource_query.type` validates against `TAG_FILTERS_1_0` only (verified
against provider 6.67.0 and current `main`;
[hashicorp/terraform-provider-aws#28690](https://github.com/hashicorp/terraform-provider-aws/issues/28690)
was closed as stale without a fix). An interface offering the type would
fail at plan with a provider error the caller cannot act on.

So `resource_query.type` accepts only `TAG_FILTERS_1_0` (and defaults to it),
and the validation message points at the working equivalent: a tag filter on
`aws:cloudformation:stack-id` with the stack's ARN, which CloudFormation sets
on every taggable resource it creates. `examples/cloudformation-stack` shows
it. The equivalence is not exact: a native stack query also lists stack
resources that cannot be tagged. The `type` attribute is kept, rather than
dropped, so that supporting the native type once the provider does is an
additive change (see Deferred to v2).

Alternatives rejected: the `awscc` provider's `awscc_resourcegroups_group`
supports the stack type, but would add a second provider to every caller of a
fleet module that otherwise uses `hashicorp/aws` alone; silently translating
`CLOUDFORMATION_STACK_1_0` into the tag query would hide the semantic
difference above.

### ADR-4: configuration types limited to the three a caller can create

AWS documents six configuration types
([Supported configuration types and parameters](https://docs.aws.amazon.com/ARG/latest/userguide/about-slg-types.html)).
The module accepts the three that a caller can create with `CreateGroup` and
a configuration alone:

| Type | Parameters the module validates |
| --- | --- |
| `AWS::ResourceGroups::Generic` | `allowed-resource-types`: exactly one of `AWS::EC2::Host`, `AWS::EC2::CapacityReservation`. `deletion-protection`: exactly `UNLESS_EMPTY`. |
| `AWS::EC2::CapacityReservationPool` | none, or `reservation-type = ["capacity-block"]` together with a single `instance-type` (UltraServer Capacity Blocks). |
| `AWS::EC2::HostManagement` | `auto-allocate-host`, `auto-release-host`, `any-host-based-license-configuration` (each one lowercase `"true"`/`"false"`), `allowed-host-families`, `allowed-host-based-license-configurations` (License Manager configuration ARNs); exactly one of the two license parameters. |

and the documented pairing rules: `CapacityReservationPool` requires a
`Generic` item allowing `AWS::EC2::CapacityReservation`; `HostManagement`
requires a `Generic` item allowing `AWS::EC2::Host` with `deletion-protection
= UNLESS_EMPTY`. With the API's maximum of two items, that makes every
accepted configuration one of: pool + Generic, host management + Generic, or
Generic alone.

The other three are rejected with a message saying why:
`AWS::AppRegistry::Application` and `AWS::CloudFormation::Stack` groups are
"fully managed by the AppRegistry service, and can't be created, updated, or
deleted by users"; `AWS::NetworkFirewall::RuleGroup` requires a configuration
**and** a tag query together, which contradicts ADR-1 (see Deferred to v2).
AppRegistry applications are created with `aws_servicecatalogappregistry_application`,
whose own resource group AWS then creates.

`instance-type` is validated by shape, not against a list: AWS's own page
spells the permitted values inconsistently (`p6e-gb200.36xlarge` in one
paragraph, `.48xlarge` in another), and new UltraServer types would otherwise
need a module release.

A Generic-only configuration is valid but can never gain members
(`GroupResources` works only on `HostManagement` and `CapacityReservationPool`
groups), so it raises the advisory check `generic_only_configuration` instead
of an error.

### ADR-5: name, description, and tags validated against the API, Name tag never overrides

`name`: 1 to 300 characters of `[a-zA-Z0-9_.-]`, not starting with `AWS` in
any capitalisation (reserved). `description`: at most 1,024 characters of
`[\sa-zA-Z0-9_.-]` — notably no commas, colons, or slashes, which AWS rejects
at apply. Tags: keys 1 to 128 and values 0 to 256 characters of letters,
digits, spaces, and `_ . : / = + - @`, keys not starting with `aws:`, and at
most 50 tags including the module's `Name` tag (a precondition, since it
counts the merged map).

The module's tag map is `merge({ Name = var.name }, var.tags)`: the caller's
map is merged last, so a caller `Name` tag always wins.

### Other bounded scope choices

- No `region` input. The provider's per-resource `region` argument exists,
  but nothing about a resource group needs a region other than the caller's
  provider; an aliased provider covers multi-region estates.
- No `timeouts`. The provider's defaults for the configuration-update wait are
  sufficient for the two service-linked types supported.
- No `DisplayName`, `Owner`, or `Criticality`. `CreateGroup` accepts them for
  application groups, but `aws_resourcegroups_group` does not expose them.

## Deferred to v2

Each of these is additive and would ship as a minor release, not a v2 major,
unless it requires a breaking change at the time:

- Native `CLOUDFORMATION_STACK_1_0` queries (a new accepted `type` and a
  `stack_arn` attribute), once `hashicorp/aws` accepts the type.
- `AWS::NetworkFirewall::RuleGroup` groups, which need a query and a
  configuration together. Supporting them means a third, explicit membership
  shape (`{ resource_query, network_firewall = true }` or similar), not
  relaxing the XOR for everyone.
- `DisplayName`, `Owner`, `Criticality` for application groups, once the
  provider exposes them.

## Failure modes

| Failure | When | What happens | Mitigation |
| --- | --- | --- | --- |
| Both or neither membership path | plan | `var.membership` validation fails, nothing sent | message names the fix |
| Malformed query, configuration, name, description, or tags | plan | variable validation fails | every documented constraint is checked |
| Rendered query over 4,096 characters | plan | precondition fails with the actual length | fewer values or resource types |
| Name already taken in the region | apply | AWS `BadRequestException` | names are unique per account and region; not checkable without a read |
| Group quota exceeded (100 per region by default) | apply | AWS error on create | raise `L-2BAA18A0` in Service Quotas |
| Name change | plan shows replace | the group is destroyed and recreated; its ARN changes | consumers referencing the ARN (SSM targets, launch templates) must follow; Application Manager shows a new application |
| Switching between query and configuration | apply | the provider refuses ("conversion between resource-query and configuration group types is not possible") | change `name` too, so the group is replaced instead of updated |
| Destroying a `HostManagement` group with members | apply | AWS refuses (`deletion-protection = UNLESS_EMPTY`, required for that type) | release or move the hosts first |
| Destroying a capacity reservation group with members | apply | the group is deleted; reservations and running instances are unaffected | none needed |
| Tag query matching nothing | never an error | the group is created empty | check `aws resource-groups list-group-resources` after tagging |
| `aws:cloudformation:stack-id` query on a stack with untaggable resources | never an error | those resources are not members | ADR-3; accept, or wait for native stack queries |

## Quotas and limits

| Limit | Value | Source |
| --- | --- | --- |
| Resource groups per account per region | 100 (adjustable, `L-2BAA18A0`) | Service Quotas |
| Configuration items per group | 2 | `CreateGroup` |
| Query string length | 4,096 characters | `ResourceQuery.Query` |
| Tag filters per query | 50 | Tagging API `TagFilters` |
| Values per tag filter | 256, each up to 256 characters | Tagging API `TagFilter` |
| Tags per group | 50 | Tagging quotas |
| Name / description length | 300 / 1,024 characters | `CreateGroup` |

AppRegistry-created groups do not count against the group quota.

## Principles and how the module applies them

- **Single responsibility.** One group, nothing else. `main.tf` renders it,
  `locals.tf` normalises and renders the query, `variables.tf` holds every
  validation, `checks.tf` the one advisory warning, `outputs.tf` the
  interface.
- **Open/closed.** A new configuration type or query type arrives as another
  accepted value and its parameter rules, without reshaping `membership`.
- **Interface segregation.** The query path's fields and the configuration
  path's fields never mix; a caller sees only the fields of the path chosen.
- **Dependency inversion.** The module depends on values (tags, ARNs), never
  on how they were produced, and performs no reads.
- **Type-system first.** Illegal shapes are type errors where HCL can say so
  (typed filters, no raw JSON), validations where a single variable can say
  so (including the XOR between `membership`'s two attributes, which share one
  variable), and preconditions only for limits of the rendered request.

## Architecture

```text
root (one resource group)
├── variables.tf   name, description, membership (resource_query | configuration, XOR validated), tags; every validation
├── locals.tf      membership mode, canonical tag filters and resource types, rendered query JSON, sorted configuration, tags
├── main.tf        aws_resourcegroups_group.this: dynamic resource_query / configuration, query-length and tag-count preconditions
├── checks.tf      generic_only_configuration (advisory)
└── outputs.tf     arn, name, membership_mode, resource_query, configuration, tags
```

## Testing strategy

- Contract tests (`tests/`) use `mock_provider` and `command = plan`; no
  credentials. `arn` is computed by AWS, so its assertion
  (`tests/outputs_apply.tftest.hcl`) uses `command = apply` with a
  `mock_resource` default, isolated in its own file.
- Every variable validation and precondition has a failing `expect_failures`
  run in `tests/validation.tftest.hcl`; each was also run without
  `expect_failures` during development to confirm it trips the intended rule
  and not a neighbouring one.
- The rendered query is asserted as an exact string, including ordering and
  the key-only spelling.
- `configuration` and its `parameters` are set-nested blocks in the provider
  schema and cannot be indexed; assertions filter by `type` first.
- `tests/integration/smoke.tftest.hcl` creates one real tag-query group with
  a time-suffixed name and destroys it.

## Compatibility

- Terraform `>= 1.7.0, < 2.0.0`.
- AWS provider `>= 6.35.0, < 7.0.0` (developed and tested against `6.67.0`).
- Nothing in the v1 interface is scheduled to change. Additions arrive as
  optional inputs, accepted values, and outputs.
