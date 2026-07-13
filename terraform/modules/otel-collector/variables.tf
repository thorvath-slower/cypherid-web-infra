variable "env" {
  type        = string
  description = "Environment name (dev/staging/prod/sandbox)."
}

variable "project" {
  type        = string
  description = "Project tag (e.g. idseq)."
}

variable "owner" {
  type        = string
  description = "Owner tag."
}

variable "region" {
  type        = string
  default     = "us-west-2"
  description = "AWS region the collector runs + exports in."
}

variable "cluster_id" {
  type        = string
  description = "ARN/id of the ECS cluster to run the collector service in."
}

variable "vpc_id" {
  type        = string
  description = "VPC the collector + app tasks live in."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnets to place the collector tasks in."
}

variable "app_ingress_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to send OTLP to the collector (typically the VPC CIDR)."
}

variable "otlp_grpc_port" {
  type    = number
  default = 4317
}

variable "otlp_http_port" {
  type    = number
  default = 4318
}

variable "collector_image" {
  type    = string
  default = "public.ecr.aws/aws-observability/aws-otel-collector:latest"
  # NOTE: pin to a digest in the consumer for reproducibility; :latest here keeps the
  # module usable without forcing a pin, but the dev/otel stack should override this.
  description = "ADOT collector image."
}

variable "cpu" {
  type    = number
  default = 256
}

variable "memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "metrics_namespace" {
  type        = string
  default     = ""
  description = "CloudWatch EMF metrics namespace. Defaults to seqtoid/<env> when empty."
}

variable "log_retention_days" {
  type    = number
  default = 365 # >= 1yr (CKV_AWS_338); override per-env if a shorter op-log window is wanted
}

variable "tags" {
  type    = map(string)
  default = {}
}
