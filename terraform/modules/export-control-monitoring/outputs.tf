output "alerts_topic_arn" {
  description = "ARN of the export-control alert SNS topic — wire on-call / compliance subscriptions here."
  value       = aws_sns_topic.alerts.arn
}

output "alarm_names" {
  description = "All export-control alarm names created by this module."
  value = compact([
    aws_cloudwatch_metric_alarm.blocked_jurisdiction.alarm_name,
    aws_cloudwatch_metric_alarm.anonymizer_hits.alarm_name,
    aws_cloudwatch_metric_alarm.total_blocked_spike.alarm_name,
    try(aws_cloudwatch_metric_alarm.fail_closed[0].alarm_name, ""),
  ])
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard (empty if not created)."
  value       = try(aws_cloudwatch_dashboard.export_control[0].dashboard_name, "")
}
