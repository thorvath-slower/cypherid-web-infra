module "eks-cluster" {
  source                  = "github.com/thorvath-slower/cztack//aws-eks-cluster?ref=v0.104.2-seqtoid.1"
  addons                  = local.addons
  authorized_github_repos = local.authorized_github_repos
  cluster_name            = local.cluster_name
  cluster_version         = local.cluster_version
  node_groups             = local.node_groups
  owner_roles             = local.owner_roles
  subnet_ids              = local.subnet_ids
  tags                    = local.tags
  vpc_id                  = local.vpc_id
  endpoint_public_access  = false # CZID #322: private control plane — reach it via the SSM bastion below


  providers = {
    aws.us-east-1 = aws.us-east-1
  }
}

# CZID #322: SSM bastion — the path to the now-private EKS API. Must exist with the flip above
# (endpoint_public_access=false) or the control plane is unreachable. Connect:
#   aws ssm start-session --target $(terraform output -raw ... bastion_instance_id)
module "ssm_bastion" {
  source                    = "../../../modules/eks-ssm-bastion"
  name                      = local.cluster_name
  vpc_id                    = local.vpc_id
  subnet_id                 = local.subnet_ids[0]
  cluster_security_group_id = module.eks-cluster.cluster_security_group
  tags                      = local.tags
}
