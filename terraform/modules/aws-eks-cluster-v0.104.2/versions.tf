terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 5.99"
      configuration_aliases = [aws.us-east-1]
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.0"
    }
    helm = {
      source = "hashicorp/helm"
      # CZID-93: this module's tree stays on helm v2. It nests
      # aws-ia/eks-blueprints-addons, which caps helm at `>= 2.9, < 3.0`, so the
      # eks stacks cannot move to v3 until that external module supports it. This
      # module creates no helm_release itself (helm is used only via the addon
      # submodules), so there is no v2 `set {}` syntax here to migrate.
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.0"
    }
  }
  required_version = "~> 1.9"
}