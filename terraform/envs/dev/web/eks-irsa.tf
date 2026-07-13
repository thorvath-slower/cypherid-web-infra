# =============================================================================
# EKS/Argo strangler (epic #319), stage 1 — the seqtoid-web pod's AWS identity (IRSA).
#
# This is the FIRST happy-gap we replace with terraform: happy provisioned the
# pod IAM role for its workloads; here we provision the seqtoid-web pod's role
# directly. It mirrors the idseq-web ECS task role's permissions EXACTLY (the app
# policy `data.aws_iam_policy_document.idseq-web` + the chamber/SSM parameter read),
# so the pod boots and connects to the same secrets / S3 / SQS / DB as the live
# ECS app. The running ECS dev is untouched (this is a new, separate role).
#
# NAMING: `seqtoid-web-<env>` — new resource, new name (strip czid). The existing
# `czid-dev-eks` cluster keeps its name (renaming a live cluster = replace).
#
# TRUST: the czid-dev-eks OIDC provider, scoped to the k8s ServiceAccount
# `seqtoid-dev/seqtoid-web`. That namespace + SA name MUST match the Helm chart's
# serviceAccount.name and the Argo destination namespace (set in stage 3).
#
# ADDITIVE — a new role + 2 inline policies. Apply with `-target` (dev/web carries
# unrelated drift): plan MUST read "3 to add, 0 to change, 0 to destroy".
# =============================================================================

# The k8s ServiceAccount the pod runs as (keep in sync with deploy/charts + dev.yaml).
locals {
  seqtoid_web_eks_namespace = "seqtoid-dev"
  seqtoid_web_eks_sa        = "seqtoid-web"

  # The pod ServiceAccount (seqtoid-dev/seqtoid-web) runs on czid-dev-eks-v2, so the role
  # trusts that cluster's OIDC provider. (History: during the czid-dev-eks -> v2 strangler
  # this map held BOTH clusters; the old czid-dev-eks was decommissioned in Phase 5, so its
  # entry + data source are removed — the data source would otherwise error now that the
  # cluster no longer exists. Kept as a map so a future second cluster is a one-line add.)
  seqtoid_web_eks_clusters = {
    "czid-dev-eks-v2" = data.aws_eks_cluster.dev_eks_v2.identity[0].oidc[0].issuer
  }
  seqtoid_web_eks_oidc = {
    for name, issuer in local.seqtoid_web_eks_clusters :
    name => {
      issuer_host  = replace(issuer, "https://", "")
      provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(issuer, "https://", "")}"
    }
  }
}

data "aws_eks_cluster" "dev_eks_v2" {
  name = "czid-dev-eks-v2"
}

# IRSA trust: only the seqtoid-web ServiceAccount in the seqtoid-dev namespace may
# assume this role — via EITHER cluster's OIDC provider (one statement per cluster).
data "aws_iam_policy_document" "seqtoid_web_eks_trust" {
  dynamic "statement" {
    for_each = local.seqtoid_web_eks_oidc
    content {
      effect  = "Allow"
      actions = ["sts:AssumeRoleWithWebIdentity"]
      principals {
        type        = "Federated"
        identifiers = [statement.value.provider_arn]
      }
      condition {
        test     = "StringEquals"
        variable = "${statement.value.issuer_host}:sub"
        values   = ["system:serviceaccount:${local.seqtoid_web_eks_namespace}:${local.seqtoid_web_eks_sa}"]
      }
      condition {
        test     = "StringEquals"
        variable = "${statement.value.issuer_host}:aud"
        values   = ["sts.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_role" "seqtoid_web_eks" {
  name               = "seqtoid-web-${var.env}"
  description        = "IRSA role for the seqtoid-web pod on czid-dev-eks (${var.env}); mirrors the idseq-web ECS task perms"
  assume_role_policy = data.aws_iam_policy_document.seqtoid_web_eks_trust.json
}

# 1) App permissions — REUSE the ECS task role's policy document for exact parity
#    (S3, SQS, Lambda, Secrets Manager, CloudWatch, Batch, etc.).
resource "aws_iam_role_policy" "seqtoid_web_eks_app" {
  name   = "seqtoid-web-${var.env}-app"
  role   = aws_iam_role.seqtoid_web_eks.id
  policy = data.aws_iam_policy_document.idseq-web.json
}

# 2) Chamber/SSM parameter read — mirrors the live idseq-dev-web-parameter-policy
#    exactly (params under /idseq-<env>-web/* + the SecureString KMS key + the
#    account-wide DescribeParameters chamber needs).
data "aws_iam_policy_document" "seqtoid_web_eks_params" {
  statement {
    actions = [
      "ssm:GetParametersByPath",
      "ssm:GetParameters",
      "ssm:GetParameterHistory",
      "ssm:GetParameter",
    ]
    resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/idseq-${var.env}-web/*"]
  }
  statement {
    actions = ["kms:Decrypt"]
    # The chamber SecureString KMS key for /idseq-<env>-web params (matches the ECS role).
    resources = ["arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:key/d60c5ad2-9fc6-4306-87cd-b0d797804f1c"]
  }
  statement {
    sid       = "ChamberSSMReadRequirement"
    actions   = ["ssm:DescribeParameters"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "seqtoid_web_eks_params" {
  name   = "seqtoid-web-${var.env}-parameter-policy"
  role   = aws_iam_role.seqtoid_web_eks.id
  policy = data.aws_iam_policy_document.seqtoid_web_eks_params.json
}

output "seqtoid_web_eks_role_arn" {
  description = "ARN of the seqtoid-web IRSA role — set as serviceAccount.roleArn in deploy/argocd/values/seqtoid-web/dev.yaml (stage 3)."
  value       = aws_iam_role.seqtoid_web_eks.arn
}
