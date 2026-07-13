# =============================================================================
# GitHub Actions PREVIEW-BUILD role — czid-dev-gh-actions-preview-build (#613).
#
# The per-PR preview build (seqtoid-web/.github/workflows/build-pr-preview.yml) runs
# on `pull_request` into `integration`. The normal build role (czid-dev-gh-actions-
# build) uses the cztack module, whose C1 guard (CZID-26) DENIES `:pull_request` OIDC
# subjects on purpose — so a PR build cannot assume it. This is a SEPARATE, deliberate,
# tightly-scoped exception that DOES allow the `:pull_request` subject.
#
# Why it's safe to allow pull_request here when the deploy role must not:
#   - Its ONLY permission is ecr push/pull to the throwaway `seqtoid-web-preview` repo
#     (created in dev/web). No deploy, no data, no SSM, no other repo, no prod.
#   - The workflow additionally gates on same-repo (fork PRs get no OIDC token at all),
#     so this trust is only ever exercised by a PR branch inside thorvath-slower/seqtoid-web.
#   - Blast radius of a malicious PR build = a junk image in seqtoid-web-preview, which
#     is never promoted and expires fast.
#
# Hand-built (not the cztack module) precisely because the module hardcodes the
# :pull_request StringNotLike deny. Reuses the dev OIDC provider from
# github-actions-runner-permissions.tf (aws_iam_openid_connect_provider.github).
# =============================================================================

data "aws_iam_policy_document" "preview_build_assume" {
  statement {
    sid     = "AllowSeqtoidWebPullRequestBuilds"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity", "sts:TagSession"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    # Deliberately allow ONLY the pull_request subject for seqtoid-web -- this role
    # exists solely for PR preview builds. (No StringNotLike deny, unlike the module.)
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for org in local.gh_orgs : "repo:${org}/seqtoid-web:pull_request"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "gh_actions_preview_build" {
  name                  = "czid-${var.env}-gh-actions-preview-build"
  assume_role_policy    = data.aws_iam_policy_document.preview_build_assume.json
  max_session_duration  = 60 * 60 # 1 hour
  force_detach_policies = true
  tags                  = var.tags
}

# Least-privilege ECR: account-wide auth token (required for docker login, cannot be
# resource-scoped) + push/pull scoped to the seqtoid-web-preview repo ONLY. The pull
# actions (BatchGetImage/GetDownloadUrlForLayer/BatchCheckLayerAvailability) let the
# build's `--cache-from` read this repo's own :buildcache; there is deliberately NO
# access to idseq-web / seqtoid-web (so a preview build cannot read or write the
# promotable images).
data "aws_iam_policy_document" "preview_build_ecr" {
  statement {
    sid       = "EcrAuthToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid = "EcrPushPullPreviewRepoOnly"
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
      "arn:aws:ecr:${var.region}:${local.account_id}:repository/seqtoid-web-preview",
    ]
  }
}

resource "aws_iam_policy" "preview_build_ecr" {
  name   = "czid-${var.env}-gh-actions-preview-build-ecr"
  policy = data.aws_iam_policy_document.preview_build_ecr.json
}

resource "aws_iam_role_policy_attachment" "preview_build_ecr" {
  role       = aws_iam_role.gh_actions_preview_build.name
  policy_arn = aws_iam_policy.preview_build_ecr.arn
}

output "preview_build_role_arn" {
  description = "ARN of czid-dev-gh-actions-preview-build (the per-PR preview build assumes this to push to seqtoid-web-preview)."
  value       = aws_iam_role.gh_actions_preview_build.arn
}
