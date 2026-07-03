module "eks-cluster" {
  source                  = "../../../modules/aws-eks-cluster-v0.104.2" # cztack v0.104.2-seqtoid.1
  addons                  = local.addons
  authorized_github_repos = local.authorized_github_repos
  cluster_name            = local.cluster_name
  cluster_version         = local.cluster_version
  node_groups             = local.node_groups
  owner_roles             = local.owner_roles
  subnet_ids              = local.subnet_ids
  tags                    = local.tags
  vpc_id                  = local.vpc_id

  # CZID #55: keep the public endpoint enabled (private flip is #322) but restrict
  # it to a scoped allow-list — never 0.0.0.0/0. Private endpoint stays on for
  # in-VPC traffic (hardcoded in the module).
  endpoint_public_access       = true
  endpoint_public_access_cidrs = local.eks_public_access_cidrs

  providers = {
    aws.us-east-1 = aws.us-east-1
  }
}
