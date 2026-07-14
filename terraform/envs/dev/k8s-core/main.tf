module "k8s-core" {
  source            = "../../../modules/k8s-core-v5.5.1"
  additional_addons = local.additional_addons
  eks_cluster       = local.eks_cluster
  tags              = local.tags



}
