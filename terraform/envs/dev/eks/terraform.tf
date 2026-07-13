provider "aws" {

  region  = "us-west-2"
  profile = "idseq-dev"

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
  allowed_account_ids = ["491013321714"]
}
# Aliased Providers (for doing things in every region).


provider "aws" {
  alias   = "us-east-1"
  region  = "us-east-1"
  profile = "idseq-dev"

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
  allowed_account_ids = ["491013321714"]
}


provider "assert" {}
terraform {
  backend "s3" {
    use_lockfile = true # bug-#006: native state locking (Terraform >= 1.10), portable (no DynamoDB)

    bucket = "tfstate-491013321714-test"

    key     = "terraform/idseq/envs/dev/components/eks.tfstate"
    encrypt = true
    region  = "us-west-2"
    profile = "idseq-dev"


  }
}
# tflint-ignore: terraform_unused_declarations
variable "env" {
  type    = string
  default = "dev"
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
  default = "eks"
}
# tflint-ignore: terraform_unused_declarations
variable "aws_profile" {
  type    = string
  default = "idseq-dev"
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
    env       = "dev"
    service   = "eks"
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
  default = "czid-dev-eks"
}
# CZID #55: allow-list of CIDRs permitted to reach the EKS public API endpoint.
# PLACEHOLDER default (RFC 5737 TEST-NET-1) — NOT a real allow-list and NEVER
# 0.0.0.0/0. Ops/counsel MUST supply the real office/VPN egress CIDRs before this
# is applied. Interim restriction only; the full private flip is #322.
variable "eks_public_access_cidrs" {
  type    = list(string)
  default = ["192.0.2.0/24"]

  validation {
    condition     = !contains(var.eks_public_access_cidrs, "0.0.0.0/0")
    error_message = "eks_public_access_cidrs must not contain 0.0.0.0/0 (CZID #55)."
  }
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
  default = "idseq-samples-dev-491013321714"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_samples_v1" {
  type    = string
  default = "czi-infectious-disease-dev-samples-491013321714"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_secrets" {
  type    = string
  default = "idseq-secrets"
}
data "terraform_remote_state" "access-management" {
  backend = "s3"
  config = {


    bucket = "tfstate-491013321714-test"

    key     = "terraform/idseq/envs/dev/components/access-management.tfstate"
    region  = "us-west-2"
    profile = "idseq-dev"


  }
}
data "terraform_remote_state" "cloud-env" {
  backend = "s3"
  config = {


    bucket = "tfstate-491013321714-test"

    key     = "terraform/idseq/envs/dev/components/cloud-env.tfstate"
    region  = "us-west-2"
    profile = "idseq-dev"


  }
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
# CZID #322: private-endpoint flip toggle. Default false = current state (public
# API endpoint ON, restricted to the #55 CIDR allow-list). Set true to make the
# control plane PRIVATE (public endpoint OFF) and stand up the SSM bastion as the
# access path — the two move together (see eks/main.tf) so there is no lockout.
# The end-user app data path is unaffected; only the cluster control plane goes
# private. The live flip is a gated apply (needs AWS + the bastion in place).
variable "eks_endpoint_private" {
  type        = bool
  default     = false
  description = "When true, disable the EKS public API endpoint (private control plane) and create the SSM bastion. Default false preserves the current CIDR-restricted public endpoint (#55)."
}
