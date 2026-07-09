terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
      # CZID-93: align with the parent k8s-core module on helm provider v3.
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.3"
}
