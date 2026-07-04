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

# Aliased provider (us-east-1) — kept for parity with the other access-management stacks.
provider "aws" {
  alias   = "us-east-1"
  region  = "us-east-1"
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

provider "assert" {}

terraform {
  backend "s3" {
    use_lockfile = true

    bucket = "tfstate-941377154785-test"

    key     = "terraform/idseq/envs/sandbox/components/access-management.tfstate"
    encrypt = true
    region  = "us-west-2"
    profile = "default"
  }
}

# tflint-ignore: terraform_unused_declarations
variable "env" {
  type    = string
  default = "sandbox"
}

# tflint-ignore: terraform_unused_declarations
variable "project" {
  type    = string
  default = "idseq"
}

variable "tags" {
  type = object({ project : string, env : string, service : string, owner : string, managedBy : string })
  default = {
    project   = "idseq"
    env       = "sandbox"
    service   = "access-management"
    owner     = "unknown"
    managedBy = "terraform"
  }
}
