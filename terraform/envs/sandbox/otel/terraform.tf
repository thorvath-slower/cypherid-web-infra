provider "aws" {
  region  = "us-west-2"
  profile = "default"

  default_tags {
    tags = {
      project   = coalesce(var.tags.project, "unknown")
      env       = coalesce(var.tags.env, "unknown")
      service   = coalesce(var.tags.service, "unknown")
      owner     = coalesce(var.tags.owner, "unknown")
      managedBy = "terraform"
    }
  }
  allowed_account_ids = ["941377154785"]
}

terraform {
  backend "s3" {
    use_lockfile = true
    bucket       = "tfstate-941377154785-test"
    key          = "terraform/idseq/envs/sandbox/components/otel.tfstate"
    encrypt      = true
    region       = "us-west-2"
    profile      = "default"
  }
}

variable "env" {
  type    = string
  default = "sandbox"
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
    env     = "sandbox"
    service = "otel"
    owner   = "idseq-eng"
  }
}

data "terraform_remote_state" "cloud-env" {
  backend = "s3"
  config = {
    bucket  = "tfstate-941377154785-test"
    key     = "terraform/idseq/envs/sandbox/components/cloud-env.tfstate"
    region  = "us-west-2"
    profile = "default"
  }
}

data "terraform_remote_state" "ecs" {
  backend = "s3"
  config = {
    bucket  = "tfstate-941377154785-test"
    key     = "terraform/idseq/envs/sandbox/components/ecs.tfstate"
    region  = "us-west-2"
    profile = "default"
  }
}
