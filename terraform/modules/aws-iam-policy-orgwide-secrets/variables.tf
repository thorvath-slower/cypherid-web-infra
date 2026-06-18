variable "role_name" {
  type        = string
  description = "The role to which this policy should be attached."
}

variable "policy_name" {
  type        = string
  description = "The name of this policy"
  default     = "ReadOrgwideSecrets"
}
