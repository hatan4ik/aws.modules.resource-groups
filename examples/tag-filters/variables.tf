variable "region" {
  description = "AWS region the resource group is created in. A group only ever contains resources from its own region."
  type        = string
  default     = "us-east-1"
}

variable "application" {
  description = "Value of the Application tag that the group's members carry, such as payments."
  type        = string
  default     = "payments"
}

variable "environment" {
  description = "Value of the Environment tag that the group's members carry, such as prod."
  type        = string
  default     = "prod"
}

variable "resource_types" {
  description = "Resource types to restrict the group to, such as AWS::EC2::Instance. Empty means every supported type."
  type        = list(string)
  default     = []
}
