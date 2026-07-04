# =============================================================================
# GitHub Actions BUILD role for the idseq-support / sandbox account (941377154785).
#
# seqtoid-web's build-docker-image.yml (auto on push to `main`, plus on-demand
# workflow_dispatch) assumes arn:aws:iam::941377154785:role/gha-seqtoid to log in
# to ECR and push the app image to the `idseq-web` (and `seqtoid-web` dual-push,
# CZID-76) repositories in THIS account. Before this stack existed there was no
# OIDC provider and no such role here, so every AssumeRoleWithWebIdentity was
# denied ("Not authorized to perform sts:AssumeRoleWithWebIdentity") and the
# build fail-closed with nothing pushed.
#
# This is a BUILD role only: it can push container images to the two named ECR
# repos and nothing else. It carries NO deploy / terraform / data permissions —
# those live in the dev account's czid-dev-gh-actions-{plan,apply} roles.
#
# Mirrors terraform/envs/dev/access-management/github-actions-runner-permissions.tf
# (same OIDC provider + aws-iam-role-github-action module + C1 pull_request deny).
# =============================================================================

locals {
  account_id = "941377154785"
  gh_org     = "thorvath-slower"
  gh_repos   = ["seqtoid-web"]

  # ECR repos this role may push to, in THIS account (CZID-76 dual-push).
  ecr_repos = ["idseq-web", "seqtoid-web"]
}

# The GitHub OIDC identity provider for this account (absent until now).
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
  client_id_list  = ["sts.amazonaws.com"]
}

# The build role. subject_ref_pattern = "*" so it works for both the push-to-main
# auto build AND on-demand workflow_dispatch test builds from a feature branch
# (the module's C1 condition still DENIES `:pull_request` subjects, so a fork PR
# can never assume it). Low blast radius: ECR push to two sandbox repos only.
module "gha_seqtoid_build" {
  source = "../../../modules/aws-iam-role-github-action-v0.104.2" # cztack v0.104.2

  tags = var.tags # TODO: var.tags is deprecated

  role = {
    name = "gha-seqtoid"
  }
  authorized_github_repos = {
    (local.gh_org) : local.gh_repos
  }
  subject_ref_pattern = "*"
}

# Least-privilege ECR push: the account-wide auth token (required for `docker
# login`, cannot be resource-scoped) + the image push/pull actions scoped to the
# two named repositories only.
data "aws_iam_policy_document" "ecr_push" {
  statement {
    sid       = "EcrAuthToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid = "EcrPushToNamedRepos"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [
      for r in local.ecr_repos :
      "arn:aws:ecr:us-west-2:${local.account_id}:repository/${r}"
    ]
  }
}

resource "aws_iam_policy" "ecr_push" {
  name   = "gha-seqtoid-ecr-push"
  policy = data.aws_iam_policy_document.ecr_push.json
}

resource "aws_iam_role_policy_attachment" "ecr_push" {
  role       = module.gha_seqtoid_build.role.name
  policy_arn = aws_iam_policy.ecr_push.arn
}

output "build_role_arn" {
  description = "ARN of the gha-seqtoid build role (set as the seqtoid-web GHA_ROLE / used by build-docker-image.yml)."
  value       = module.gha_seqtoid_build.role.arn
}

output "github_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}
