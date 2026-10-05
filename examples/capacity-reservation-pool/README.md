# Capacity reservation pool

The `configuration` membership path: a service-linked group that EC2 uses as a
pool of On-Demand Capacity Reservations. It has no query; reservations are
added to it explicitly (the `GroupResources` API or the EC2 console), and an
instance or launch template that targets the group's ARN
(`capacity_reservation_specification.capacity_reservation_target.capacity_reservation_resource_group_arn`)
launches into whichever reservation in the pool has room.

AWS requires the pool item to be paired with an `AWS::ResourceGroups::Generic`
item allowing only `AWS::EC2::CapacityReservation`; the module rejects the
pool without it at plan time.

## Run

```sh
terraform init
terraform plan
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
| <a name="input_name"></a> [name](#input\_name) | Name of the capacity reservation group. | `string` | `"batch-capacity-pool"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region of the Capacity Reservations the pool will hold. | `string` | `"us-east-1"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_configuration"></a> [configuration](#output\_configuration) | The group's normalized service configuration. |
| <a name="output_group_arn"></a> [group\_arn](#output\_group\_arn) | ARN of the capacity reservation group; use it as capacity\_reservation\_target.capacity\_reservation\_resource\_group\_arn on an instance or launch template. |
<!-- END_TF_DOCS -->
