output "dashboard_name" {
  description = "Core-services dashboard name (null if not created)."
  value       = var.create_dashboard ? aws_cloudwatch_dashboard.core_services[0].dashboard_name : null
}

output "alarm_count" {
  description = "Total number of alarms created by this module."
  value = (
    length(aws_cloudwatch_metric_alarm.ecs_cpu_high)
    + length(aws_cloudwatch_metric_alarm.ecs_memory_high)
    + length(aws_cloudwatch_metric_alarm.ecs_running_tasks_low)
    + length(aws_cloudwatch_metric_alarm.rds_cpu_high)
    + length(aws_cloudwatch_metric_alarm.rds_connections_high)
    + length(aws_cloudwatch_metric_alarm.rds_replica_lag_high)
    + length(aws_cloudwatch_metric_alarm.rds_free_storage_low)
    + length(aws_cloudwatch_metric_alarm.opensearch_cluster_red)
    + length(aws_cloudwatch_metric_alarm.opensearch_jvm_pressure_high)
    + length(aws_cloudwatch_metric_alarm.opensearch_free_storage_low)
    + length(aws_cloudwatch_metric_alarm.alb_5xx_high)
    + length(aws_cloudwatch_metric_alarm.alb_target_response_time_high)
    + length(aws_cloudwatch_metric_alarm.alb_unhealthy_hosts)
    + length(aws_cloudwatch_metric_alarm.lambda_errors)
    + length(aws_cloudwatch_metric_alarm.lambda_throttles)
  )
}
