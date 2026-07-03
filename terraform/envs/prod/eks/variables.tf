locals {
  owner_roles = [
    "poweruser",
    "okta-czi-admin",
    "tfe-si",
  ]

  cluster_name            = var.eks_cluster_name
  iam_cluster_name_prefix = ""

  tags            = var.tags
  vpc_id          = data.terraform_remote_state.cloud-env.outputs.vpc_id
  subnet_ids      = data.terraform_remote_state.cloud-env.outputs.private_subnets
  cluster_version = "1.35"

  node_groups = {
    "arm" = {
      max_servers   = 20
      capacity_type = "ON_DEMAND"
      architecture = {
        ami_type       = "AL2023_ARM_64_STANDARD"
        instance_types = ["t4g.xlarge"]
      }
    },
    // please push teams to use ARM, this is just a backup in case you need it
    "x86" = {
      max_servers   = 10
      capacity_type = "ON_DEMAND"
      architecture = {
        ami_type       = "AL2023_x86_64_STANDARD"
        instance_types = ["t3.xlarge"]
      }
    }
  }
  # Retired dead entry (#468/#439): "czid-graphql-federation-server" under the
  # upstream "chanzuckerberg" org is CZI migration residue — a dead repo in an org
  # we don't deploy from (ours is thorvath-slower). The real GitHub OIDC
  # deploy-role trust is owned by the access-management stack (D1/CZID-81/26),
  # which federates thorvath-slower. This cluster grant was never wired to a live
  # repo, so it is emptied rather than repointed — an empty map is a valid
  # map(list(string)) and produces zero trust statements. If the cluster later
  # needs to grant repo access, add the specific thorvath-slower repo(s) here.
  authorized_github_repos = {}
  addons = {
    enable_guardduty = true
  }
}
