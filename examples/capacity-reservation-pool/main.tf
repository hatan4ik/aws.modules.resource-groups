provider "aws" {
  region = var.region
}

# A service-linked group: no query. Capacity Reservations are added to it
# explicitly (the GroupResources API, or the EC2 console), and an instance
# launched with this group's ARN as its capacity reservation target draws from
# any reservation in it.
module "resource_group" {
  source = "../../"

  name        = var.name
  description = "Shared pool of EC2 On-Demand Capacity Reservations"

  membership = {
    configuration = [
      { type = "AWS::EC2::CapacityReservationPool" },
      {
        # AWS requires this companion item: only capacity reservations may
        # be members of a capacity reservation pool.
        type       = "AWS::ResourceGroups::Generic"
        parameters = { "allowed-resource-types" = ["AWS::EC2::CapacityReservation"] }
      },
    ]
  }
}
