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

variable "subnet_id_account_a" {
  type        = string
  description = "Subnet ID in target account A (must have internet access)"
}

variable "subnet_id_account_b" {
  type        = string
  description = "Subnet ID in target account B (must have internet access)"
}

variable "security_group_id_account_a" {
  type        = string
  description = "Security group ID in target account A"
}

variable "security_group_id_account_b" {
  type        = string
  description = "Security group ID in target account B"
}
