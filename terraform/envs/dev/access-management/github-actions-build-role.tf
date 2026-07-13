# =============================================================================
# GitHub Actions BUILD role — czid-dev-gh-actions-build (dev account, 491013321714).
#
# seqtoid-web's build-docker-image.yml assumes this role to log in to ECR and push
# the app image to the dev `idseq-web` repository (dev/web). It reuses the dev OIDC
# provider already created in this stack (github-actions-runner-permissions.tf) —
# no new provider.
#
# This is a BUILD role only: ECR push to the named dev repo(s) and nothing else. No
# terraform / deploy / data permissions (those are czid-dev-gh-actions-{plan,apply}).
#
# NOTE (isolated-envs / D5): the deploy must NOT touch the idseq-support account
# (941377154785). The build-docker-image.yml default of CI_ACCOUNT_ID=941377154785
# was a stale idseq shared-registry holdover; it is retargeted to this dev account
# (491013321714), where the app actually runs and pulls its image from.
# =============================================================================

# Build only ever runs for seqtoid-web (the app image); scope the trust to it, not
# the whole gh_repos list. subject_ref_pattern="*" supports both the push-to-main
# auto build and on-demand workflow_dispatch test builds; the module's C1 guard
# still DENIES :pull_request subjects (a fork PR can never assume it).
module "czid_gh_actions_build" {
  source = "../../../modules/aws-iam-role-github-action-v0.104.2" # cztack v0.104.2

  tags = var.tags # TODO: var.tags is deprecated

  role = {
    name = "czid-${var.env}-gh-actions-build"
  }
  authorized_github_repos = {
    for org in local.gh_orgs : org => ["seqtoid-web"]
  }
  subject_ref_pattern = "*"
}

# Least-privilege ECR push: account-wide auth token (required for `docker login`,
# cannot be resource-scoped) + image push/pull scoped to the named repo(s) only.
# seqtoid-web is included for the CZID-76 dual-push once that repo is added to
# dev/web; scoping to a not-yet-created repo ARN is harmless (matches nothing).
data "aws_iam_policy_document" "build_ecr_push" {
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
      "arn:aws:ecr:${var.region}:${local.account_id}:repository/idseq-web",
      "arn:aws:ecr:${var.region}:${local.account_id}:repository/seqtoid-web",
    ]
  }
}

resource "aws_iam_policy" "build_ecr_push" {
  name   = "czid-${var.env}-gh-actions-build-ecr-push"
  policy = data.aws_iam_policy_document.build_ecr_push.json
}

resource "aws_iam_role_policy_attachment" "build_ecr_push" {
  role       = module.czid_gh_actions_build.role.name
  policy_arn = aws_iam_policy.build_ecr_push.arn
}

output "build_role_arn" {
  description = "ARN of czid-dev-gh-actions-build (the seqtoid-web build assumes this to push to dev ECR)."
  value       = module.czid_gh_actions_build.role.arn
}
