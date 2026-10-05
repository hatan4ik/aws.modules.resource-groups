# Security policy

## Supported versions

| Version | Supported |
| --- | --- |
| 1.x | Yes. Security fixes and functional fixes on the latest minor release. |
| Unreleased `main` | Not supported for production use. |

## Reporting a vulnerability

Use GitHub private vulnerability reporting on this repository: open the Security tab and choose "Report a vulnerability". Do not open a public issue, pull request, or discussion for a security problem.

Include the module version or commit SHA, the inputs that reproduce the problem, the resulting plan, and the impact you see.

## What counts

- A membership bypass: a group created with both a resource query and a service configuration, or with neither, despite the precondition.
- A query that does not mean what the inputs say: a rendered query that drops, merges, or widens a tag filter or resource type filter, so the group contains resources the caller did not select. Group membership drives Systems Manager targeting, so an over-wide group can send commands to the wrong instances.
- A validation bypass: an input the module claims to reject at plan time (a malformed name, description, tag, tag filter, configuration type, or configuration parameter, or a missing configuration pairing) that reaches the provider instead.
- A tag precedence regression: the module's `Name` tag overriding a caller's `Name` tag.
- A dependency problem in the release pipeline that could publish unverified code.

Findings in your own inputs (for example a tag filter broad enough to match resources you did not intend) or in AWS services themselves are out of scope here; report the latter to AWS.

## Response

We acknowledge a report within 5 business days and keep you informed while we confirm, fix, and release. A fix ships as a patch release with a `CHANGELOG.md` entry that credits the reporter unless they ask otherwise. Please give us a reasonable window before disclosing publicly.

## Security design

A resource group holds no data and grants no access by itself, but it is an input to systems that act on its members: Systems Manager Run Command, State Manager, and Maintenance Windows target groups by name, and EC2 launches into capacity reservation groups by ARN. The module's security posture is therefore precision: membership is built from typed filters rather than caller-written JSON, rendered canonically and exposed as an output so it can be reviewed in a plan, and every documented AWS constraint is checked at plan time. It creates no IAM resources and performs no data-source reads. The reasoning is in [docs/DESIGN.md](docs/DESIGN.md).
