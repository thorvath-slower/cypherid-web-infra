# =============================================================================
# service-monitoring — core-services CloudWatch alarms + dashboard (CZID-157)
# -----------------------------------------------------------------------------
# The baseline monitoring layer for the web-infra core services: ECS services,
# Aurora RDS, OpenSearch, the ALB, and Lambda. One SSOT module, consumed by a
# per-env `monitoring` stack (dev/staging/prod/sandbox).
#
# Each resource group self-disables when its identifier input is empty/absent, so
# an env only creates the alarms for the services it actually runs. Alarm actions
# fan out to var.alarm_actions_sns_topic_arn (a per-env placeholder — the shared
# alerts topic). When that ARN is empty the alarms are still created but carry no
# actions, so the module is apply-safe before the topic exists.
#
# Authored, NOT applied. Thresholds are conservative starting points, tunable per
# env once real baselines are observed.
# =============================================================================

locals {
  name    = "czid-${var.env}"
  actions = var.alarm_actions_sns_topic_arn == "" ? [] : [var.alarm_actions_sns_topic_arn]

  ecs_enabled        = var.ecs_cluster_name != "" && length(var.ecs_service_names) > 0
  rds_enabled        = var.rds_cluster_identifier != ""
  opensearch_enabled = var.opensearch_domain_name != "" && var.opensearch_account_id != ""
  alb_enabled        = var.alb_arn_suffix != ""
  lambda_enabled     = length(var.lambda_function_names) > 0

  ecs_services = local.ecs_enabled ? toset(var.ecs_service_names) : toset([])
  lambda_fns   = local.lambda_enabled ? toset(var.lambda_function_names) : toset([])
}

# =============================================================================
# ECS services — CPU / memory / running task count
# =============================================================================
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  for_each = local.ecs_services

  alarm_name          = "${local.name}-ecs-${each.value}-cpu-high"
  alarm_description   = "ECS service ${each.value} CPU utilization sustained high — ${var.env}."
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  dimensions          = { ClusterName = var.ecs_cluster_name, ServiceName = each.value }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.ecs_cpu_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  for_each = local.ecs_services

  alarm_name          = "${local.name}-ecs-${each.value}-memory-high"
  alarm_description   = "ECS service ${each.value} memory utilization sustained high — ${var.env}."
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  dimensions          = { ClusterName = var.ecs_cluster_name, ServiceName = each.value }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.ecs_memory_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_running_tasks_low" {
  for_each = local.ecs_services

  alarm_name          = "${local.name}-ecs-${each.value}-running-tasks-low"
  alarm_description   = "ECS service ${each.value} running task count dropped below ${var.ecs_min_running_tasks} — ${var.env}."
  namespace           = "ECS/ContainerInsights"
  metric_name         = "RunningTaskCount"
  dimensions          = { ClusterName = var.ecs_cluster_name, ServiceName = each.value }
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.ecs_min_running_tasks
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags
}

# =============================================================================
# Aurora / RDS — CPU / connections / replica lag / free storage
# =============================================================================
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  count = local.rds_enabled ? 1 : 0

  alarm_name          = "${local.name}-rds-cpu-high"
  alarm_description   = "Aurora ${var.rds_cluster_identifier} CPU utilization sustained high — ${var.env}."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = { DBClusterIdentifier = var.rds_cluster_identifier }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.rds_cpu_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  count = local.rds_enabled ? 1 : 0

  alarm_name          = "${local.name}-rds-connections-high"
  alarm_description   = "Aurora ${var.rds_cluster_identifier} database connections near capacity — ${var.env}."
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  dimensions          = { DBClusterIdentifier = var.rds_cluster_identifier }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.rds_connections_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_replica_lag_high" {
  count = local.rds_enabled ? 1 : 0

  alarm_name          = "${local.name}-rds-replica-lag-high"
  alarm_description   = "Aurora ${var.rds_cluster_identifier} replica lag high (replica falling behind writer) — ${var.env}."
  namespace           = "AWS/RDS"
  metric_name         = "AuroraReplicaLag"
  dimensions          = { DBClusterIdentifier = var.rds_cluster_identifier }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.rds_replica_lag_threshold_seconds * 1000 # metric is milliseconds
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage_low" {
  count = local.rds_enabled ? 1 : 0

  alarm_name          = "${local.name}-rds-free-storage-low"
  alarm_description   = "Aurora ${var.rds_cluster_identifier} free local storage low — ${var.env}."
  namespace           = "AWS/RDS"
  metric_name         = "FreeLocalStorage"
  dimensions          = { DBClusterIdentifier = var.rds_cluster_identifier }
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.rds_free_storage_threshold_bytes
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags
}

# FreeableMemory low: distinct from FreeLocalStorage (disk) — memory exhaustion
# forces swapping / OOM and is a classic Aurora degradation mode. CZID-157.
resource "aws_cloudwatch_metric_alarm" "rds_freeable_memory_low" {
  count = local.rds_enabled ? 1 : 0

  alarm_name          = "${local.name}-rds-freeable-memory-low"
  alarm_description   = "Aurora ${var.rds_cluster_identifier} freeable memory low (memory pressure / risk of swap+OOM) — ${var.env}."
  namespace           = "AWS/RDS"
  metric_name         = "FreeableMemory"
  dimensions          = { DBClusterIdentifier = var.rds_cluster_identifier }
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.rds_freeable_memory_threshold_bytes
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags
}

# =============================================================================
# OpenSearch — cluster status (red) / JVM memory pressure / free storage
# =============================================================================
resource "aws_cloudwatch_metric_alarm" "opensearch_cluster_red" {
  count = local.opensearch_enabled ? 1 : 0

  alarm_name          = "${local.name}-opensearch-cluster-red"
  alarm_description   = "OpenSearch domain ${var.opensearch_domain_name} cluster status RED (primary shards unassigned) — ${var.env}."
  namespace           = "AWS/ES"
  metric_name         = "ClusterStatus.red"
  dimensions          = { DomainName = var.opensearch_domain_name, ClientId = var.opensearch_account_id }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "opensearch_jvm_pressure_high" {
  count = local.opensearch_enabled ? 1 : 0

  alarm_name          = "${local.name}-opensearch-jvm-pressure-high"
  alarm_description   = "OpenSearch domain ${var.opensearch_domain_name} JVM memory pressure high (GC / OOM risk) — ${var.env}."
  namespace           = "AWS/ES"
  metric_name         = "JVMMemoryPressure"
  dimensions          = { DomainName = var.opensearch_domain_name, ClientId = var.opensearch_account_id }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.opensearch_jvm_pressure_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "opensearch_free_storage_low" {
  count = local.opensearch_enabled ? 1 : 0

  alarm_name          = "${local.name}-opensearch-free-storage-low"
  alarm_description   = "OpenSearch domain ${var.opensearch_domain_name} free storage space low — ${var.env}."
  namespace           = "AWS/ES"
  metric_name         = "FreeStorageSpace"
  dimensions          = { DomainName = var.opensearch_domain_name, ClientId = var.opensearch_account_id }
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.opensearch_free_storage_threshold_mb
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags
}

# =============================================================================
# ALB — 5xx / target response time / unhealthy hosts
# =============================================================================
resource "aws_cloudwatch_metric_alarm" "alb_5xx_high" {
  count = local.alb_enabled ? 1 : 0

  alarm_name          = "${local.name}-alb-5xx-high"
  alarm_description   = "ALB elevated 5xx responses — ${var.env}."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.alb_5xx_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "alb_target_response_time_high" {
  count = local.alb_enabled ? 1 : 0

  alarm_name          = "${local.name}-alb-target-response-time-high"
  alarm_description   = "ALB target response time high (backend latency) — ${var.env}."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.alb_target_response_time_threshold_seconds
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  count = local.alb_enabled ? 1 : 0

  alarm_name          = "${local.name}-alb-unhealthy-hosts"
  alarm_description   = "ALB reports unhealthy targets behind the load balancer — ${var.env}."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags
}

# =============================================================================
# Lambda — errors / throttles
# =============================================================================
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = local.lambda_fns

  alarm_name          = "${local.name}-lambda-${each.value}-errors"
  alarm_description   = "Lambda ${each.value} errors — ${var.env}."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = each.value }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.lambda_errors_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  for_each = local.lambda_fns

  alarm_name          = "${local.name}-lambda-${each.value}-throttles"
  alarm_description   = "Lambda ${each.value} throttles (concurrency limit) — ${var.env}."
  namespace           = "AWS/Lambda"
  metric_name         = "Throttles"
  dimensions          = { FunctionName = each.value }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.lambda_throttles_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags
}
