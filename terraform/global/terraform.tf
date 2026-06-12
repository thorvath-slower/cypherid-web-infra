provider "aws" {

  region  = "us-west-2"
  profile = "invalid-profile"

  # this is the new way of injecting AWS tags to all AWS resources
  # var.tags should be considered deprecated
  default_tags {
    tags = {
      project   = coalesce(var.tags.project, "unknown")
      env       = coalesce(var.tags.env, "unknown")
      service   = coalesce(var.tags.service, "unknown")
      owner     = coalesce(var.tags.owner, "unknown")
      managedBy = "terraform"
    }
  }
  allowed_account_ids = ["invalid-account-id"]
}
# Aliased Providers (for doing things in every region).


provider "aws" {
  alias   = "us-east-1"
  region  = "us-east-1"
  profile = "invalid-profile"

  # this is the new way of injecting AWS tags to all AWS resources
  # var.tags should be considered deprecated
  default_tags {
    tags = {
      project   = coalesce(var.tags.project, "unknown")
      env       = coalesce(var.tags.env, "unknown")
      service   = coalesce(var.tags.service, "unknown")
      owner     = coalesce(var.tags.owner, "unknown")
      managedBy = "terraform"
    }
  }
  allowed_account_ids = ["invalid-account-id"]
}


provider "aws" {
  alias   = "czi-si-us-east-1"
  region  = "us-east-1"
  profile = "idseq-prod"

  # this is the new way of injecting AWS tags to all AWS resources
  # var.tags should be considered deprecated
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


provider "aws" {
  alias   = "czi-si"
  region  = "us-west-2"
  profile = "idseq-prod"

  # this is the new way of injecting AWS tags to all AWS resources
  # var.tags should be considered deprecated
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


provider "assert" {}
terraform {
  backend "" {

  }
}
# tflint-ignore: terraform_unused_declarations
variable "env" {
  type    = string
  default = ""
}
# tflint-ignore: terraform_unused_declarations
variable "project" {
  type    = string
  default = "idseq"
}
# tflint-ignore: terraform_unused_declarations
variable "region" {
  type    = string
  default = "us-west-2"
}
# tflint-ignore: terraform_unused_declarations
variable "component" {
  type    = string
  default = "global"
}
# tflint-ignore: terraform_unused_declarations
variable "aws_profile" {
  type    = string
  default = "invalid-profile"
}
# tflint-ignore: terraform_unused_declarations
variable "owner" {
  type    = string
  default = "biohub-tech@chanzuckerberg.com"
}
# tflint-ignore: terraform_unused_declarations
# DEPRECATED: this field is deprecated in favor or 
# AWS provider default tags.
variable "tags" {
  type = object({ project : string, env : string, service : string, owner : string, managedBy : string })
  default = {
    project   = "idseq"
    env       = ""
    service   = "global"
    owner     = "biohub-tech@chanzuckerberg.com"
    managedBy = "terraform"
  }
}
# tflint-ignore: terraform_unused_declarations
variable "alignment_index_date" {
  type    = string
  default = "2021-01-22"
}
# tflint-ignore: terraform_unused_declarations
variable "base_domain" {
  type    = string
  default = "seqtoid.org"
}
# tflint-ignore: terraform_unused_declarations
variable "build_index_date" {
  type    = string
  default = "2021-01-22"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_idseq_bench" {
  type    = string
  default = "idseq-bench"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_public_references" {
  type    = string
  default = "seqtoid-public-references"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_secrets" {
  type    = string
  default = "idseq-secrets"
}
# tflint-ignore: terraform_unused_declarations
variable "aws_accounts" {
  type = map(string)
  default = {

  }
}
