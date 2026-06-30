variable "name_prefix" {
  type    = string
  default = "seqtoid"
}

variable "env" {
  type        = string
  description = "Environment name (dev/staging/prod/sandbox)."
}

variable "retention_days" {
  type        = number
  default     = 90
  description = "Days to retain CloudFront access logs before expiry."
}

variable "tags" {
  type    = map(string)
  default = {}
}
