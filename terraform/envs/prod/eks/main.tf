module "eks-cluster" {
  source                  = "../../../modules/aws-eks-cluster-v0.104.2" # cztack v0.104.2-seqtoid.1
  addons                  = local.addons
  authorized_github_repos = local.authorized_github_repos
  cluster_name            = local.cluster_name
  cluster_version         = local.cluster_version
  iam_cluster_name_prefix = local.iam_cluster_name_prefix
  node_groups             = local.node_groups
  owner_roles             = local.owner_roles
  subnet_ids              = local.subnet_ids
  tags                    = local.tags
  vpc_id                  = local.vpc_id


  providers = {
    aws.us-east-1 = aws.us-east-1
  }
}
