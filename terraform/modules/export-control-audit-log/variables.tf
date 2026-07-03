# CZID-331 — immutable, retained audit-log store for the export-control evidence trail.
# Authored, NOT applied (bucket-b). The retention period is a COUNSEL determination.

variable "name" {
  description = "Base name for the audit store (the bucket is named aws-waf-logs-<name>-<account>, so WAF can deliver to it directly)."
  type        = string
}

variable "retention_days" {
  description = "Object Lock retention, in days — the export record-keeping period. COUNSEL-OWNED (CZID-322/331): commonly ~1825 (5 years), but export record-keeping vs privacy caps is counsel's balance. No default: it must be set deliberately."
  type        = number
}

variable "object_lock_mode" {
  description = "S3 Object Lock mode. COMPLIANCE = no one (not even root) can shorten/remove the lock within the window — required for a zero-tolerance evidence trail. GOVERNANCE = overridable with a special permission. Default COMPLIANCE."
  type        = string
  default     = "COMPLIANCE"
  validation {
    condition     = contains(["COMPLIANCE", "GOVERNANCE"], var.object_lock_mode)
    error_message = "object_lock_mode must be COMPLIANCE or GOVERNANCE."
  }
}

variable "kms_key_arn" {
  description = "Optional KMS CMK ARN for SSE-KMS. Empty = SSE-S3 (AES256)."
  type        = string
  default     = ""
}

variable "create_edge_log_firehose" {
  description = "Create a Firehose delivery stream so the Layer-2 edge Lambda decision logs (CloudWatch, per edge-region) can be centralized into this immutable store. The per-region CloudWatch subscription filter that feeds it is wired in the consuming stack (see README)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags (expects at least project/env/service)."
  type        = map(string)
  default     = {}
}
