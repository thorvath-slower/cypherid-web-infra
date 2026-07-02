provider "aws" {
  region  = "us-west-2"
  profile = "idseq-staging"

  default_tags {
    tags = {
      project   = coalesce(var.tags.project, "unknown")
      env       = coalesce(var.tags.env, "unknown")
      service   = coalesce(var.tags.service, "unknown")
      owner     = coalesce(var.tags.owner, "unknown")
      managedBy = "terraform"
    }
  }
  allowed_account_ids = ["030998640247"]
}

terraform {
  backend "s3" {
    use_lockfile = true
    bucket       = "tfstate-030998640247"
    key          = "terraform/idseq/envs/staging/components/otel.tfstate"
    encrypt      = true
    region       = "us-west-2"
    profile      = "idseq-staging"
  }
}

variable "env" {
  type    = string
  default = "staging"
}

variable "project" {
  type    = string
  default = "idseq"
}

variable "component" {
  type    = string
  default = "otel"
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
    env     = "staging"
    service = "otel"
    owner   = "idseq-eng"
  }
}

data "terraform_remote_state" "cloud-env" {
  backend = "s3"
  config = {
    bucket  = "tfstate-030998640247"
    key     = "terraform/idseq/envs/staging/components/cloud-env.tfstate"
    region  = "us-west-2"
    profile = "idseq-staging"
  }
}

data "terraform_remote_state" "ecs" {
  backend = "s3"
  config = {
    bucket  = "tfstate-030998640247"
    key     = "terraform/idseq/envs/staging/components/ecs.tfstate"
    region  = "us-west-2"
    profile = "idseq-staging"
  }
}
