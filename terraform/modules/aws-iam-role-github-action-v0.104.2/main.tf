data "aws_caller_identity" "current" {}

locals {
  idp     = "token.actions.githubusercontent.com"
  idp_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.idp}"
}

// https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services#adding-the-identity-provider-to-aws
data "aws_iam_policy_document" "assume_role" {
  dynamic "statement" {
    for_each = var.authorized_aws_accounts

    content {
      sid = "AllowAssumeRoleFrom${statement.key}"
      principals {
        type        = "AWS"
        identifiers = ["arn:aws:iam::${statement.value}:root"]
      }
      actions = ["sts:AssumeRole", "sts:TagSession"]
      effect  = "Allow"
    }
  }
  dynamic "statement" {
    for_each = var.authorized_github_repos

    content {
      sid = replace("Allow${statement.key}ToAssumeRole", "-", "")
      principals {
        type        = "Federated"
        identifiers = [local.idp_arn]
      }

      actions = ["sts:AssumeRoleWithWebIdentity", "sts:TagSession"]
      # subject_ref_pattern defaults to "*" (any branch/tag/environment), which
      # preserves the historical behavior for every existing consumer. Callers
      # that must restrict which git refs may assume the role (e.g. an apply role
      # limited to `refs/heads/main`) set it to a narrower glob such as
      # "refs/heads/main". The `:pull_request` StringNotLike below still applies.
      condition {
        test     = "StringLike"
        variable = "${local.idp}:sub"
        values = formatlist(
          "repo:%s/%s:${var.subject_ref_pattern}",
          statement.key,
          statement.value,
        )
      }
      # C1 (CZID-26 / CI-CD audit): exclude pull_request-triggered runs — a PR,
      # especially from a fork, must never be able to assume the deploy role.
      # Branch / tag / environment subjects still match the StringLike above; only
      # the `:pull_request` subject is denied (StringNotLike is ANDed with the allow).
      condition {
        test     = "StringNotLike"
        variable = "${local.idp}:sub"
        values = formatlist(
          "repo:%s/%s:pull_request",
          statement.key,
          statement.value,
        )
      }
      # Defense-in-depth: require the AWS STS audience (also pinned on the OIDC
      # provider's client_id_list).
      condition {
        test     = "StringEquals"
        variable = "${local.idp}:aud"
        values   = ["sts.amazonaws.com"]
      }
    }
  }
}

data "aws_iam_policy_document" "this" {
  source_policy_documents = compact([
    data.aws_iam_policy_document.assume_role.json,
    var.additional_assume_role_policies_json,
  ])
}

resource "aws_iam_role" "role" {
  name = var.role.name

  tags = var.tags

  assume_role_policy   = data.aws_iam_policy_document.this.json
  max_session_duration = 60 * 60 // 1 hour, not sure what max github action exec time is

  # We have to force detach policies in order to recreate roles.
  # The other option would be to use name_prefix and create_before_destroy, but that
  # doesn't work if you want a role with a stable, memorable name.
  force_detach_policies = true
}
