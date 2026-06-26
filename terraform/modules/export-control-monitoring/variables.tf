# CZID-332 — monitoring + alerting for the export-control controls. Authored, not applied.
# Recipients, thresholds, and the eventual apply are owned by the compliance office + Tom (bucket-b).

variable "web_acl_name" {
  description = "Name of the export-control regional WAF web ACL to monitor."
  type        = string
}

variable "region" {
  description = "Region the regional WAF runs in — its AWS/WAFV2 CloudWatch metrics live here."
  type        = string
}

variable "alert_emails" {
  description = "Addresses subscribed to the export-control alert topic (on-call + compliance). The real recipients are owned by the compliance office (CZID-334); pass them from the env stack, never hard-code here."
  type        = list(string)
  default     = []
}

# Rule metric names — must match the web-acl module's visibility_config metric_name values.
variable "geo_block_metric_name" {
  description = "Metric name of the geo-block rule group (blocked-jurisdiction attempts). Depends on the deployed geo rule-group name, so it has no default — pass it from the env stack."
  type        = string
}

variable "anonymizer_metric_name" {
  description = "Metric name of the AnonymousIpList rule (VPN/proxy/Tor/hosting hits). SINGLE SOURCE: wire from the web-acl module — module.<web_acl>.rule_metric_names.anonymous_ip — never re-type the literal (it would drift from the rule that emits it)."
  type        = string
}

# Alarm thresholds. Defaults are conservative starting points; tune per env during the canary.
variable "blocked_jurisdiction_alarm_threshold" {
  description = "Alarm when blocked-jurisdiction attempts in a 5-min window reach this. Deliberately low — any sustained signal is an export-control event worth review."
  type        = number
  default     = 1
}

variable "anonymizer_alarm_threshold" {
  description = "Alarm when anonymizer (VPN/proxy/Tor/hosting) blocks in a 5-min window exceed this. Tune to filter normal background noise vs a real surge."
  type        = number
  default     = 50
}

variable "total_blocked_alarm_threshold" {
  description = "Alarm when total WAF-blocked requests in a 5-min window exceed this (broad anomaly / false-positive surge signal)."
  type        = number
  default     = 500
}

variable "fail_closed_log_group_name" {
  description = "CloudWatch log group of the Layer-2 edge Lambda, for the fail-closed (provider_error) metric filter + alarm. Empty disables it. NOTE: Lambda@Edge logs are written per edge-region (/aws/lambda/<region>.<fn>); point this at an aggregated group, or instantiate the alarm per-region in the consuming stack. See README."
  type        = string
  default     = ""
}

variable "fail_closed_alarm_threshold" {
  description = "Alarm when fail-closed (provider_error) denials in a 5-min window exceed this — the IP-intel provider is degraded and legitimate users are being denied."
  type        = number
  default     = 5
}

variable "create_dashboard" {
  description = "Create the CloudWatch dashboard summarizing the export-control signals."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Resource tags. Expects at least project/env/service, like the other modules."
  type        = map(string)
  default     = {}
}
