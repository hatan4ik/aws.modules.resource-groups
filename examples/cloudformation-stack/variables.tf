variable "region" {
  description = "AWS region of the CloudFormation stack. The group is created in the same region."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name of the resource group."
  type        = string
  default     = "payments-stack"
}

variable "stack_name" {
  description = "Name of the CloudFormation stack, used only in the group's description."
  type        = string
  default     = "payments"
}

variable "stack_arn" {
  description = "Full ARN of the CloudFormation stack whose resources form the group (aws cloudformation describe-stacks --stack-name <name> --query 'Stacks[0].StackId')."
  type        = string
  default     = "arn:aws:cloudformation:us-east-1:123456789012:stack/payments/11111111-2222-3333-4444-555555555555"
}
