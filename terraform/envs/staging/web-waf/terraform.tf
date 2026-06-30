provider "aws" {

  region  = "us-west-2"
  profile = "idseq-staging"

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
  allowed_account_ids = ["030998640247"]
}
# Aliased Providers (for doing things in every region).


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


provider "aws" {
  alias   = "us-east-1"
  region  = "us-east-1"
  profile = "idseq-staging"

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
  allowed_account_ids = ["030998640247"]
}


provider "assert" {}
terraform {
  backend "s3" {
    use_lockfile = true # bug-#006: native state locking (Terraform >= 1.10), portable (no DynamoDB)

    bucket = "tfstate-030998640247"

    key     = "terraform/idseq/envs/staging/components/web-waf.tfstate"
    encrypt = true
    region  = "us-west-2"
    profile = "idseq-staging"


  }
}
# tflint-ignore: terraform_unused_declarations
variable "env" {
  type    = string
  default = "staging"
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
  default = "web-waf"
}
# tflint-ignore: terraform_unused_declarations
variable "aws_profile" {
  type    = string
  default = "idseq-staging"
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
    env       = "staging"
    service   = "web-waf"
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
variable "eks_cluster_name" {
  type    = string
  default = "czid-staging-eks"
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
variable "s3_bucket_samples" {
  type    = string
  default = "idseq-samples-staging-030998640247"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_samples_v1" {
  type    = string
  default = "czi-infectious-disease-staging-samples-030998640247"
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

    idseq-dev = "491013321714"

    idseq-prod = "283694049553"

    idseq-staging = "030998640247"

    idseq-support = "941377154785"

  }
}
