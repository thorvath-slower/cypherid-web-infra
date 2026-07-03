# CZID-331 (#288) — immutable audit logging + retention of every access decision.
#
# This stack stands up the export-control compliance evidence trail:
#   1. export-control-audit-log  — the immutable (S3 Object Lock, COMPLIANCE) + retained evidence store,
#      versioned + SSE + public-access-blocked + TLS-only, with an optional Firehose to centralize the
#      Layer-2 edge Lambda's per-request decision logs into it.
#   2. export-control-monitoring — CloudWatch alarms + SNS + dashboard over the Layer-1 WAF decision metrics
#      (blocked-jurisdiction, anonymizer, total blocks) and the Layer-2 fail-closed signal.
#
# AWS-GATED (bucket-b) — AUTHORING ONLY. Nothing here is applied. The retention period + alert recipients
# are counsel/compliance determinations (see variables). Apply is gated on Tom + counsel sign-off (#292).
#
# DEPENDENCY NOTE: the Layer-1 export-control WAF (#280/#281/#282, epic CZID-321) is NOT yet on integration.
# Its web-ACL name + geo/anonymizer rule-metric names are therefore parameterized here as variables rather
# than read from remote state, so this stack `validate`s standalone. When the Layer-1 WAF lands, wire these
# from the web-waf stack's outputs (module.web-service-waf.web_acl_name /
# .rule_metric_names.anonymous_ip) via terraform_remote_state instead of the literal defaults.

# --- Immutable, retained evidence store (S3 Object Lock COMPLIANCE + versioning + SSE + PAB + TLS-only) ---
module "export_control_audit_log" {
  source = "../../../modules/export-control-audit-log"

  name             = "seqtoid-${var.tags.env}-export-control"
  retention_days   = var.audit_log_retention_days # COUNSEL-OWNED (CZID-331): no default — set deliberately.
  object_lock_mode = var.audit_log_object_lock_mode
  kms_key_arn      = var.audit_log_kms_key_arn

  # Centralize the Layer-2 edge Lambda decision logs into the immutable store (per-region CloudWatch
  # subscription filter → this Firehose is wired in the edge stack once the Lambda is applied — see the
  # module README). The Firehose target exists so the subscription has somewhere to land.
  create_edge_log_firehose = var.create_edge_log_firehose

  tags = var.tags
}

# --- Monitoring + alerting over the access-decision signals ---
module "export_control_monitoring" {
  source = "../../../modules/export-control-monitoring"

  # SSOT once Layer-1 WAF is on integration: wire these from the web-waf stack outputs. Until then they are
  # parameterized (see the dependency note above) so this stack validates standalone.
  web_acl_name           = var.web_acl_name
  geo_block_metric_name  = var.geo_block_metric_name
  anonymizer_metric_name = var.anonymizer_metric_name
  region                 = var.region

  # Compliance-owned recipients (CZID-334) — passed in, never hard-coded. Empty is valid; the topic still
  # exists as an alarm target.
  alert_emails = var.export_control_alert_emails

  # Optional Layer-2 fail-closed alarm — needs the edge Lambda log group (Lambda@Edge logs per edge-region).
  # Empty disables it (default); wire once the edge Lambda is applied.
  fail_closed_log_group_name = var.fail_closed_log_group_name

  tags = var.tags
}
