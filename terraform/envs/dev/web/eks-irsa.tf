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
  # The czid-dev-eks OIDC provider (registered for IRSA). Issuer host without scheme.
  eks_oidc_issuer_host  = replace(data.aws_eks_cluster.dev_eks.identity[0].oidc[0].issuer, "https://", "")
  eks_oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.eks_oidc_issuer_host}"
}

data "aws_eks_cluster" "dev_eks" {
  name = "czid-dev-eks"
}

# IRSA trust: only the seqtoid-web ServiceAccount in the seqtoid-dev namespace may
# assume this role, via the cluster's OIDC provider.
data "aws_iam_policy_document" "seqtoid_web_eks_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.eks_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:${local.seqtoid_web_eks_namespace}:${local.seqtoid_web_eks_sa}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
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
