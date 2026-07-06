# =============================================================================
# service-monitoring — inputs (CZID-157)
# =============================================================================

variable "env" {
  description = "Environment name (dev|staging|prod|sandbox) — used in alarm/dashboard names."
  type        = string
}

variable "region" {
  description = "AWS region (for dashboard metric ARNs)."
  type        = string
  default     = "us-west-2"
}

variable "alarm_actions_sns_topic_arn" {
  description = <<-EOT
    SNS topic ARN alarms fire to (and clear to, for the OK transition). PLACEHOLDER
    per env — the foundation's shared alerts topic (czid-infra monitoring.tf) or a
    web-infra-owned topic. When empty, alarms are still created but have no actions,
    so the module is safe to apply before the topic exists.
  EOT
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}

# --- ECS services -------------------------------------------------------------
variable "ecs_cluster_name" {
  description = "ECS cluster name (dimension for the service alarms). Empty disables ECS alarms."
  type        = string
  default     = ""
}

variable "ecs_service_names" {
  description = "ECS service names to alarm on (CPU/memory/running-task-count)."
  type        = list(string)
  default     = []
}

variable "ecs_cpu_threshold" {
  type    = number
  default = 85
}

variable "ecs_memory_threshold" {
  type    = number
  default = 85
}

variable "ecs_min_running_tasks" {
  description = "Alarm if a service's running task count drops below this."
  type        = number
  default     = 1
}

# --- Aurora / RDS -------------------------------------------------------------
variable "rds_cluster_identifier" {
  description = "Aurora cluster identifier (DBClusterIdentifier dimension). Empty disables RDS alarms."
  type        = string
  default     = ""
}

variable "rds_cpu_threshold" {
  type    = number
  default = 85
}

variable "rds_connections_threshold" {
  description = "DatabaseConnections alarm threshold. Tune to the instance class max_connections."
  type        = number
  default     = 400
}

variable "rds_replica_lag_threshold_seconds" {
  type    = number
  default = 30
}

variable "rds_free_storage_threshold_bytes" {
  description = "FreeLocalStorage low-water alarm (bytes). Default 10 GiB."
  type        = number
  default     = 10737418240
}

variable "rds_freeable_memory_threshold_bytes" {
  description = "FreeableMemory low-water alarm (bytes) — memory pressure, distinct from disk. Default 512 MiB; tune to the instance class RAM."
  type        = number
  default     = 536870912
}

# --- OpenSearch / Elasticsearch ----------------------------------------------
variable "opensearch_domain_name" {
  description = "OpenSearch/Elasticsearch domain name. Empty disables OpenSearch alarms."
  type        = string
  default     = ""
}

variable "opensearch_account_id" {
  description = "Account id owning the OpenSearch domain (ClientId dimension for AWS/ES metrics)."
  type        = string
  default     = ""
}

variable "opensearch_jvm_pressure_threshold" {
  type    = number
  default = 80
}

variable "opensearch_free_storage_threshold_mb" {
  description = "FreeStorageSpace low-water alarm (MB). Default 10240 MB (10 GiB)."
  type        = number
  default     = 10240
}

# --- ALB ----------------------------------------------------------------------
variable "alb_arn_suffix" {
  description = "ALB ARN suffix (LoadBalancer dimension, e.g. app/my-alb/abc123). Empty disables ALB alarms."
  type        = string
  default     = ""
}

variable "alb_5xx_threshold" {
  type    = number
  default = 10
}

variable "alb_target_response_time_threshold_seconds" {
  type    = number
  default = 2
}

# --- Lambda -------------------------------------------------------------------
variable "lambda_function_names" {
  description = "Lambda function names to alarm on (errors + throttles). Empty disables Lambda alarms."
  type        = list(string)
  default     = []
}

variable "lambda_errors_threshold" {
  type    = number
  default = 1
}

variable "lambda_throttles_threshold" {
  type    = number
  default = 1
}

# --- Dashboard ----------------------------------------------------------------
variable "create_dashboard" {
  description = "Create the core-services CloudWatch dashboard."
  type        = bool
  default     = true
}
