variable "region" {
  type    = string
  default = "us-east-1"
}

variable "target_account_a_id" {
  type        = string
  description = "AWS Account ID for target account A"
}

variable "target_account_b_id" {
  type        = string
  description = "AWS Account ID for target account B"
}
