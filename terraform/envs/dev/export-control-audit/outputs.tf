output "audit_log_bucket_id" {
  description = "The immutable (Object Lock COMPLIANCE) export-control audit-log bucket — WAF/Firehose log destination."
  value       = module.export_control_audit_log.bucket_id
}

output "audit_log_bucket_arn" {
  description = "ARN of the immutable audit-log bucket."
  value       = module.export_control_audit_log.bucket_arn
}

output "edge_log_firehose_arn" {
  description = "ARN of the edge-decision Firehose (empty if not created) — the per-region CloudWatch subscription filter targets this."
  value       = module.export_control_audit_log.firehose_arn
}

output "alerts_topic_arn" {
  description = "ARN of the export-control alert SNS topic — wire on-call / compliance subscriptions here."
  value       = module.export_control_monitoring.alerts_topic_arn
}

output "alarm_names" {
  description = "All export-control CloudWatch alarm names."
  value       = module.export_control_monitoring.alarm_names
}

output "dashboard_name" {
  description = "Name of the export-control CloudWatch dashboard (empty if not created)."
  value       = module.export_control_monitoring.dashboard_name
}
