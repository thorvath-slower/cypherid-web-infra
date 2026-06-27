# AWS Load Balancer Controller IRSA role (CZID-321) — via the shared SSOT module
# terraform/modules/lb-controller-irsa. After apply, fill the Argo CD LBC Application's
# REPLACE_LBC_IAM_ROLE_ARN placeholder with the lb_controller_role_arn output below.
module "lb_controller_irsa" {
  source = "../../../modules/lb-controller-irsa"

  cluster_name      = local.cluster_name
  oidc_provider_arn = module.eks-cluster.oidc_provider_arn
  tags              = local.tags
}

output "lb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller — fill into the Argo CD LBC Application."
  value       = module.lb_controller_irsa.role_arn
}
