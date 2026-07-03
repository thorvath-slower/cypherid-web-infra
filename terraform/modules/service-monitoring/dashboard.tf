# =============================================================================
# service-monitoring — core-services CloudWatch dashboard (CZID-157)
# -----------------------------------------------------------------------------
# One dashboard summarizing the core services. Widgets are assembled
# conditionally from the same enable flags as the alarms, so an env only shows
# panels for the services it runs. Built in HCL (jsonencode) rather than a
# templatefile so the widget list can be composed with for-expressions.
# =============================================================================

locals {
  dashboard_enabled = var.create_dashboard

  ecs_widgets = local.ecs_enabled ? [
    {
      type   = "metric"
      width  = 12
      height = 6
      properties = {
        title  = "ECS CPU / Memory (%)"
        region = var.region
        view   = "timeSeries"
        metrics = flatten([
          for s in var.ecs_service_names : [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", s],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", s],
          ]
        ])
      }
    }
  ] : []

  rds_widgets = local.rds_enabled ? [
    {
      type   = "metric"
      width  = 12
      height = 6
      properties = {
        title  = "Aurora RDS"
        region = var.region
        view   = "timeSeries"
        metrics = [
          ["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", var.rds_cluster_identifier],
          ["AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", var.rds_cluster_identifier],
          ["AWS/RDS", "AuroraReplicaLag", "DBClusterIdentifier", var.rds_cluster_identifier],
        ]
      }
    }
  ] : []

  opensearch_widgets = local.opensearch_enabled ? [
    {
      type   = "metric"
      width  = 12
      height = 6
      properties = {
        title  = "OpenSearch"
        region = var.region
        view   = "timeSeries"
        metrics = [
          ["AWS/ES", "ClusterStatus.red", "DomainName", var.opensearch_domain_name, "ClientId", var.opensearch_account_id],
          ["AWS/ES", "JVMMemoryPressure", "DomainName", var.opensearch_domain_name, "ClientId", var.opensearch_account_id],
          ["AWS/ES", "FreeStorageSpace", "DomainName", var.opensearch_domain_name, "ClientId", var.opensearch_account_id],
        ]
      }
    }
  ] : []

  alb_widgets = local.alb_enabled ? [
    {
      type   = "metric"
      width  = 12
      height = 6
      properties = {
        title  = "ALB"
        region = var.region
        view   = "timeSeries"
        metrics = [
          ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix],
          ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix],
          ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", var.alb_arn_suffix],
        ]
      }
    }
  ] : []

  lambda_widgets = local.lambda_enabled ? [
    {
      type   = "metric"
      width  = 12
      height = 6
      properties = {
        title  = "Lambda errors / throttles"
        region = var.region
        view   = "timeSeries"
        metrics = flatten([
          for fn in var.lambda_function_names : [
            ["AWS/Lambda", "Errors", "FunctionName", fn],
            ["AWS/Lambda", "Throttles", "FunctionName", fn],
          ]
        ])
      }
    }
  ] : []

  dashboard_widgets = concat(
    local.ecs_widgets,
    local.rds_widgets,
    local.opensearch_widgets,
    local.alb_widgets,
    local.lambda_widgets,
  )
}

resource "aws_cloudwatch_dashboard" "core_services" {
  count = local.dashboard_enabled ? 1 : 0

  dashboard_name = "czid-${var.env}-core-services"
  dashboard_body = jsonencode({ widgets = local.dashboard_widgets })
}
