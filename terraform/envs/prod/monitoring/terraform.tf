provider "aws" {
  region  = "us-west-2"
  profile = "idseq-prod"

  default_tags {
    tags = {
      project   = coalesce(var.tags.project, "unknown")
      env       = coalesce(var.tags.env, "unknown")
      service   = coalesce(var.tags.service, "unknown")
      owner     = coalesce(var.tags.owner, "unknown")
      managedBy = "terraform"
    }
  }
  allowed_account_ids = ["283694049553"]
}

terraform {
  backend "s3" {
    use_lockfile = true
    bucket       = "tfstate-283694049553"
    key          = "terraform/idseq/envs/prod/components/monitoring.tfstate"
    encrypt      = true
    region       = "us-west-2"
    profile      = "idseq-prod"
  }
}

variable "env" {
  type    = string
  default = "prod"
}

variable "project" {
  type    = string
  default = "idseq"
}

variable "component" {
  type    = string
  default = "monitoring"
}

variable "owner" {
  type    = string
  default = "idseq-eng"
}

variable "region" {
  type    = string
  default = "us-west-2"
}

variable "tags" {
  type = object({
    project = string
    env     = string
    service = string
    owner   = string
  })
  default = {
    project = "idseq"
    env     = "prod"
    service = "monitoring"
    owner   = "idseq-eng"
  }
}

# --- SNS topic ARN alarms fire to. PLACEHOLDER per env: the shared alerts topic
# --- (czid-infra foundation monitoring.tf) or a web-infra-owned topic. Empty is
# --- apply-safe (alarms created without actions). Set via TF_VAR_alarm_actions_sns_topic_arn.
variable "alarm_actions_sns_topic_arn" {
  type    = string
  default = ""
}

# ECS cluster id comes from the ecs stack's remote state; service names + the
# other resource identifiers are env inputs (default empty => that alarm group
# is skipped). Override per env as the services come online.
data "terraform_remote_state" "ecs" {
  backend = "s3"
  config = {
    bucket  = "tfstate-283694049553"
    key     = "terraform/idseq/envs/prod/components/ecs.tfstate"
    region  = "us-west-2"
    profile = "idseq-prod"
  }
}
