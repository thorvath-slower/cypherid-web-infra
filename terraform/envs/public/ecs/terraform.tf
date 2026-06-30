# TODO(revisit): this `public` stack is EMPTY — no resources or modules, only
# provider/backend/remote_state scaffolding (validated by bug-#013, but it
# provisions nothing). Confirm whether the `public` environment is still live;
# if it is dead, delete the whole environment rather than maintain empty stacks.

provider "aws" {

  region  = "us-west-2"
  profile = "idseq-dev"

  allowed_account_ids = [732052188396]
}
# Aliased Providers (for doing things in every region).


provider "aws" {
  alias   = "us-east-1"
  region  = "us-east-1"
  profile = "idseq-dev"

  allowed_account_ids = [732052188396]
}


provider "aws" {
  alias   = "us-west-2"
  region  = "us-west-2"
  profile = "idseq-dev"

  allowed_account_ids = [732052188396]
}

terraform {
  backend "s3" {
    use_lockfile = true # bug-#006: native state locking (Terraform >= 1.10), portable (no DynamoDB)

    bucket = "idseq-terraform-infra"

    key     = "terraform/idseq/envs/public/components/ecs.tfstate"
    encrypt = true
    region  = "us-west-2"
    profile = "idseq-dev"


  }
}
variable "env" {
  type    = string
  default = "public"
}
variable "project" {
  type    = string
  default = "idseq"
}
variable "region" {
  type    = string
  default = "us-west-2"
}
variable "component" {
  type    = string
  default = "ecs"
}
variable "aws_profile" {
  type    = string
  default = "idseq-dev"
}
variable "owner" {
  type    = string
  default = "biohub-tech@chanzuckerberg.com"
}
variable "tags" {
  type = object({ project : string, env : string, service : string, owner : string, managedBy : string })
  default = {
    project   = "idseq"
    env       = "public"
    service   = "ecs"
    owner     = "biohub-tech@chanzuckerberg.com"
    managedBy = "terraform"
  }
}
variable "alignment_index_date" {
  type    = string
  default = "2020-04-20"
}
variable "build_index_date" {
  type    = string
  default = "2020-04-20"
}
variable "s3_bucket_idseq_bench" {
  type    = string
  default = "idseq-bench"
}
variable "s3_bucket_public_references" {
  type    = string
  default = "idseq-public-references"
}
variable "s3_bucket_secrets" {
  type    = string
  default = "idseq-secrets"
}
variable "s3_bucket_workflows" {
  type    = string
  default = "idseq-workflows"
}
data "terraform_remote_state" "global" {
  backend = "s3"
  config = {


    bucket = "idseq-terraform-infra"

    key     = "terraform/idseq/global.tfstate"
    region  = "us-west-2"
    profile = "idseq-dev"


  }
}
data "terraform_remote_state" "cloud-env" {
  backend = "s3"
  config = {


    bucket = "idseq-terraform-infra"

    key     = "terraform/idseq/envs/public/components/cloud-env.tfstate"
    region  = "us-west-2"
    profile = "idseq-dev"


  }
}
data "terraform_remote_state" "db" {
  backend = "s3"
  config = {


    bucket = "idseq-terraform-infra"

    key     = "terraform/idseq/envs/public/components/db.tfstate"
    region  = "us-west-2"
    profile = "idseq-dev"


  }
}
data "terraform_remote_state" "elasticsearch" {
  backend = "s3"
  config = {


    bucket = "idseq-terraform-infra"

    key     = "terraform/idseq/envs/public/components/elasticsearch.tfstate"
    region  = "us-west-2"
    profile = "idseq-dev"


  }
}
data "terraform_remote_state" "elb-access-logs" {
  backend = "s3"
  config = {


    bucket = "idseq-terraform-infra"

    key     = "terraform/idseq/envs/public/components/elb-access-logs.tfstate"
    region  = "us-west-2"
    profile = "idseq-dev"


  }
}
data "terraform_remote_state" "redis" {
  backend = "s3"
  config = {


    bucket = "idseq-terraform-infra"

    key     = "terraform/idseq/envs/public/components/redis.tfstate"
    region  = "us-west-2"
    profile = "idseq-dev"


  }
}
data "terraform_remote_state" "resque" {
  backend = "s3"
  config = {


    bucket = "idseq-terraform-infra"

    key     = "terraform/idseq/envs/public/components/resque.tfstate"
    region  = "us-west-2"
    profile = "idseq-dev"


  }
}
data "terraform_remote_state" "web" {
  backend = "s3"
  config = {


    bucket = "idseq-terraform-infra"

    key     = "terraform/idseq/envs/public/components/web.tfstate"
    region  = "us-west-2"
    profile = "idseq-dev"


  }
}
# remote state for accounts
data "terraform_remote_state" "idseq-dev" {
  backend = "s3"
  config = {


    bucket = "idseq-terraform-infra"

    key     = "terraform/idseq/accounts/idseq-dev.tfstate"
    region  = "us-west-2"
    profile = "idseq-dev"


  }
}
# map of aws_accounts
variable "aws_accounts" {
  type = map(any)
  default = {


    idseq-dev = 732052188396


  }
}
provider "random" {
}
provider "archive" {
}
provider "null" {
}
provider "local" {
}
provider "tls" {
}