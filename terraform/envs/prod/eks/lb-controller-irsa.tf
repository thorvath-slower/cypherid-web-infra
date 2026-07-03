# AWS Load Balancer Controller IRSA role (CZID #321) — via the shared SSOT module
# terraform/modules/lb-controller-irsa. The controller is installed cluster-wide
# via GitOps (deploy/argocd/apps/aws-load-balancer-controller.yaml); it assumes
# this role to manage ALBs/target groups for app Ingresses.
#
# BOOTSTRAP (post-apply, per cluster/account): take lb_controller_role_arn below
# and fill it into the Argo CD LBC Application's REPLACE_LBC_IAM_ROLE_ARN.
module "lb_controller_irsa" {
  source = "../../../modules/lb-controller-irsa"

  cluster_name      = local.cluster_name
  oidc_provider_arn = module.eks-cluster.oidc_provider_arn
  oidc_issuer_url   = module.eks-cluster.cluster_oidc_issuer_url
  tags              = local.tags
}

output "lb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller — fill into the Argo CD LBC Application's REPLACE_LBC_IAM_ROLE_ARN."
  value       = module.lb_controller_irsa.role_arn
}
