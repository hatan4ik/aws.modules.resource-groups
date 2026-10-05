variable "region" {
  description = "AWS region of the Capacity Reservations the pool will hold."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name of the capacity reservation group."
  type        = string
  default     = "batch-capacity-pool"
}
