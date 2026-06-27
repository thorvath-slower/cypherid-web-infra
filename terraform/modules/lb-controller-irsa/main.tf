# Shared SSOT module: the AWS Load Balancer Controller IRSA role (CZID-321). One definition; every EKS env
# instantiates it with its own cluster name + OIDC provider. The controller (installed via the Argo CD
# Application) assumes this role to manage ALBs/target groups for app Ingresses.
module "this" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39" # pin a current v5.x that ships attach_load_balancer_controller_policy

  role_name                              = "${var.cluster_name}-aws-load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = var.tags
}
