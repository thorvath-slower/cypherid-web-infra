variable "cluster_name" {
  type        = string
  description = "EKS cluster name — used to name the role/policy so each env's IRSA role is distinct."
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the cluster's IAM OIDC provider (module.eks-cluster.oidc_provider_arn)."
}

variable "oidc_issuer_url" {
  type        = string
  description = "The cluster's OIDC issuer URL (module.eks-cluster.cluster_oidc_issuer_url) — used to scope the trust policy conditions."
}

variable "service_account_namespace" {
  type        = string
  default     = "kube-system"
  description = "Namespace of the AWS Load Balancer Controller service account. Must match the Argo CD LBC Application (kube-system)."
}

variable "service_account_name" {
  type        = string
  default     = "aws-load-balancer-controller"
  description = "Name of the AWS Load Balancer Controller service account. Must match the Argo CD LBC Application."
}

variable "permissions_boundary_arn" {
  type        = string
  default     = null
  description = "Optional IAM permissions boundary ARN to attach to the role."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to the IAM role and policy."
}
