# Changelog

All notable changes to this module are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Consumers pin the commit SHA of a release tag; see [Versioning and releases](README.md#versioning-and-releases).

## [Unreleased]

### Changed

- The "exactly one of `membership.resource_query` or `membership.configuration`" rule is now a `validation` on `var.membership` instead of a `lifecycle.precondition` on `aws_resourcegroups_group.this`. Same condition and message, still rejected at plan time; the error is now reported against the variable. `locals.tf` no longer carries the defensive "both or neither" fallback, and the `main.tf` comment that claimed a variable validation could not express the choice is corrected. No plan change for any valid caller.

### Fixed

- `.github/workflows/integration.yml`: the version comments on the pinned `actions/checkout` (`v7.0.1`) and `aws-actions/configure-aws-credentials` (`v6.3.0`) SHAs named the wrong releases. The pinned SHAs are unchanged.

## [1.0.0] - 2026-10-05

Initial version. One `aws_resourcegroups_group` per module call.

### Added

- `name` (1 to 300 characters of `[a-zA-Z0-9_.-]`, not starting with `AWS` in any capitalisation), `description` (nullable; at most 1,024 characters of `[\sa-zA-Z0-9_.-]`), and `tags` (caller tags win over the module's `Name` tag; key, value, and `aws:` prefix rules validated; at most 50 tags including `Name`).
- `membership`, one required object with two mutually exclusive attributes, enforced by a precondition:
  - `resource_query`: `TAG_FILTERS_1_0` queries built from typed `tag_filters` (`{ key, values }`, 1 to 50, distinct keys, empty `values` meaning any value) and `resource_type_filters` (empty meaning `AWS::AllSupported`), rendered canonically to AWS's JSON query string and checked against the 4,096-character limit. `CLOUDFORMATION_STACK_1_0` is rejected at plan time because the AWS provider rejects it; the message points to the `aws:cloudformation:stack-id` tag filter instead.
  - `configuration`: 1 or 2 service configuration items of `AWS::ResourceGroups::Generic`, `AWS::EC2::CapacityReservationPool`, or `AWS::EC2::HostManagement`, with each type's documented parameters and AWS's pairing rules validated.
- Advisory check `generic_only_configuration`: warns when a configuration holds only a Generic item, which can never gain members.
- Outputs `arn`, `name`, `membership_mode`, `resource_query` (type, rendered query, normalised tag and resource-type filters), `configuration` (normalised, sorted by type), and `tags`.
- Examples `tag-filters`, `cloudformation-stack`, and `capacity-reservation-pool`.
- Mock-provider contract tests for both membership paths, every validation and precondition, the advisory check, and every output; a credential-driven `smoke` integration suite.

[Unreleased]: https://github.com/hatan4ik/aws.modules.resource-groups/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/hatan4ik/aws.modules.resource-groups/releases/tag/v1.0.0
