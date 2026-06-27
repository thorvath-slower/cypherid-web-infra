variable "cluster_name" {
  description = "EKS cluster name; the role is named <cluster_name>-aws-load-balancer-controller."
  type        = string
}

variable "oidc_provider_arn" {
  description = "The cluster's IRSA OIDC provider ARN (module.eks-cluster.oidc_provider_arn)."
  type        = string
}

variable "tags" {
  description = "Tags to apply to the role."
  type        = map(string)
  default     = {}
}
