# AWS Load Balancer Controller — IRSA role (CZID-321).
# The controller (installed via the Argo CD Application in cypherid-web-infra/deploy/argocd/apps/
# aws-load-balancer-controller.yaml) assumes this role through IRSA to manage the ALB + target groups for
# the seqtoid-web Ingress. After apply, fill that Application's REPLACE_LBC_IAM_ROLE_ARN placeholder with
# the lb_controller_role_arn output below (per env).
module "lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39" # pin a current v5.x that ships attach_load_balancer_controller_policy

  role_name                              = "${local.cluster_name}-aws-load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks-cluster.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.tags
}

output "lb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller — fill into the Argo CD LBC Application."
  value       = module.lb_controller_irsa.iam_role_arn
}
