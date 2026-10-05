provider "aws" {
  region = var.region
}

module "resource_group" {
  source = "../../"

  name        = "${var.application}-${var.environment}"
  description = "Every resource of ${var.application} in ${var.environment}"

  # Members: every resource tagged with this application AND either of the
  # environment's stages, AND any CostCenter value at all. Membership is
  # re-evaluated continuously; tagging a new resource adds it.
  membership = {
    resource_query = {
      tag_filters = [
        { key = "Application", values = [var.application] },
        { key = "Environment", values = [var.environment] },
        { key = "CostCenter" },
      ]
      resource_type_filters = var.resource_types
    }
  }

  tags = {
    Application = var.application
    Environment = var.environment
  }
}
