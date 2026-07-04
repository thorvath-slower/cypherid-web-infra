# CZID-157 — core-services baseline alarms + dashboard for sandbox.
#
# Consumes the SSOT terraform/modules/service-monitoring. Each alarm group is
# skipped unless its identifier is supplied, so this stack is apply-safe from day
# one and grows as identifiers are filled in. The RDS cluster identifier follows
# the db stack convention ("${project}-${env}"). ECS cluster id is read from
# the ecs stack's remote state.

module "service_monitoring" {
  source = "../../../modules/service-monitoring"

  env    = var.env
  region = var.region
  tags   = var.tags

  alarm_actions_sns_topic_arn = var.alarm_actions_sns_topic_arn

  # ECS: cluster from remote state; add service names as they are deployed.
  ecs_cluster_name  = try(data.terraform_remote_state.ecs.outputs.cluster_id, "")
  ecs_service_names = var.ecs_service_names

  # Aurora: identifier follows the db stack naming ("${project}-${env}").
  rds_cluster_identifier = var.rds_cluster_identifier

  # OpenSearch / ALB / Lambda: fill per env as the resources come online.
  opensearch_domain_name = var.opensearch_domain_name
  opensearch_account_id  = var.opensearch_account_id
  alb_arn_suffix         = var.alb_arn_suffix
  lambda_function_names  = var.lambda_function_names
}

variable "ecs_service_names" {
  type    = list(string)
  default = []
}

variable "rds_cluster_identifier" {
  type    = string
  default = "idseq-sandbox"
}

variable "opensearch_domain_name" {
  type    = string
  default = ""
}

variable "opensearch_account_id" {
  type    = string
  default = "941377154785"
}

variable "alb_arn_suffix" {
  type    = string
  default = ""
}

variable "lambda_function_names" {
  type    = list(string)
  default = []
}
