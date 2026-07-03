# CZID-331 (#288) — variables for the export-control immutable-audit stack.
# AWS-gated (bucket-b). Retention + recipients are counsel/compliance determinations.

# --- Immutable store ---

variable "audit_log_retention_days" {
  description = <<-EOT
    Object Lock retention, in days — the export-control record-keeping period. COUNSEL-OWNED
    (design doc §9 open-decision #5, CZID-331): the doc does NOT fix a number; it is counsel's balance of
    export record-keeping (commonly ~1825 = 5 years) against privacy-law caps on retained PII.
    Conservative default is 1825 (5 years), CLEARLY MARKED FOR COUNSEL — confirm before any apply.
    COMPLIANCE mode cannot be shortened once written, so the number must be right the first time.
  EOT
  type        = number
  default     = 1825 # ~5yr placeholder — FLAG FOR COUNSEL (CZID-331). Do not apply un-confirmed.
}

variable "audit_log_object_lock_mode" {
  description = "S3 Object Lock mode. COMPLIANCE (default) = immutable within the window, not even by root — required for a zero-tolerance evidence trail. GOVERNANCE = overridable with a special permission."
  type        = string
  default     = "COMPLIANCE"
  validation {
    condition     = contains(["COMPLIANCE", "GOVERNANCE"], var.audit_log_object_lock_mode)
    error_message = "audit_log_object_lock_mode must be COMPLIANCE or GOVERNANCE."
  }
}

variable "audit_log_kms_key_arn" {
  description = "Optional KMS CMK ARN for SSE-KMS on the audit store. Empty = SSE-S3 (AES256)."
  type        = string
  default     = ""
}

variable "create_edge_log_firehose" {
  description = "Create the Firehose delivery stream so the Layer-2 edge Lambda decision logs (CloudWatch, per edge-region) can be centralized into the immutable store. The per-region subscription filter that feeds it is wired in the edge stack once that Lambda is applied."
  type        = bool
  default     = true
}

# --- Monitoring (Layer-1 WAF decision metrics) ---
# Parameterized until the Layer-1 export-control WAF (#280/#281/#282) lands on integration; then wire from
# the web-waf stack outputs via remote state. Defaults match the deployed metric naming convention.

variable "web_acl_name" {
  description = "Name of the export-control regional WAF web ACL to monitor. Wire from module.web-service-waf.web_acl_name once the Layer-1 WAF is on integration."
  type        = string
  default     = "seqtoid-web-acl"
}

variable "geo_block_metric_name" {
  description = "Metric name of the geo-block rule group (blocked-jurisdiction attempts, CZID-323). Wire from the waf-georestriction-main / web-acl outputs once Layer-1 lands."
  type        = string
  default     = "seqtoid-georestriction-metrics"
}

variable "anonymizer_metric_name" {
  description = "Metric name of the AnonymousIpList rule (VPN/proxy/Tor/hosting hits, CZID-324). Wire from module.web-service-waf.rule_metric_names.anonymous_ip once Layer-1 lands — never re-type the literal."
  type        = string
  default     = "anonymous-ip-metrics"
}

variable "export_control_alert_emails" {
  description = "Addresses subscribed to the export-control alert topic (on-call + compliance). COMPLIANCE-OWNED (CZID-334) — pass from the env, never hard-code. Empty is valid."
  type        = list(string)
  default     = []
}

variable "fail_closed_log_group_name" {
  description = "CloudWatch log group of the Layer-2 edge Lambda, for the fail-closed (provider_error) metric filter + alarm. Empty disables it (default). Lambda@Edge logs are per edge-region; point at an aggregated group or instantiate per-region in the edge stack."
  type        = string
  default     = ""
}
