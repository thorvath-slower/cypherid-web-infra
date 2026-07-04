variable "tags" {
  description = "Tags/identity for the log bucket. project/env/service also derive the bucket name."
  type        = object({ project : string, env : string, service : string, owner : string, managedBy : string })
}

variable "log_retention_days" {
  type        = number
  description = "CloudFront access logs are expired after this many days."
  default     = 365
}

variable "force_destroy" {
  type        = bool
  description = "Allow terraform to destroy the log bucket even if non-empty."
  default     = true
}
