terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Lambda@Edge resources MUST be created in us-east-1, so the consumer passes a us-east-1
      # provider alias in:  providers = { aws = aws, aws.useast1 = aws.useast1 }
      configuration_aliases = [aws.useast1]
    }
  }
}
