terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100.0"
      # CLOUDFRONT-scoped WAF must be created in us-east-1. The caller passes an aliased provider:
      #   providers = { aws = aws.us-east-1 }
      configuration_aliases = [aws]
    }
  }
  required_version = ">= 0.13"
}
