terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    # tls provider removed (CZID-42): the key is no longer generated in Terraform, so this module
    # no longer needs the tls provider. The Secrets Manager secret is created empty/placeholder and
    # the real key is provisioned out of band.
  }
}
