# Module-local provider constraints (kept minimal per the repo convention — modules
# declare only what they use and do NOT inherit the root stacks' full _shared list).
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
