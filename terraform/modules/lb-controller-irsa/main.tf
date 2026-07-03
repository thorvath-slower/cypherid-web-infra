# Shared SSOT module: the AWS Load Balancer Controller IRSA role (CZID #321).
#
# One definition; every EKS env instantiates it with its own cluster name + OIDC
# provider ARN. The AWS Load Balancer Controller — installed cluster-wide via the
# Argo CD Application in deploy/argocd/apps/aws-load-balancer-controller.yaml —
# runs under the kube-system:aws-load-balancer-controller service account and
# assumes this role (IRSA) to manage ALBs/target groups for app Ingresses.
#
# Vendoring note (Constitution Principle II/III): the IAM permission set is the
# canonical AWS Load Balancer Controller policy, vendored in-tree as
# iam-policy.json and pinned by version (see that file's header) rather than
# pulled from a registry module — no network at init, no drift, one source of
# truth. Re-vendor procedure: replace iam-policy.json from the pinned upstream
# release and bump the header comment.

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    # Scope the trust to exactly the controller's service account.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.service_account_namespace}:${var.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

locals {
  oidc_provider_url = replace(var.oidc_issuer_url, "https://", "")
}

resource "aws_iam_role" "this" {
  name                 = "${var.cluster_name}-aws-load-balancer-controller"
  description          = "IRSA role for the AWS Load Balancer Controller on ${var.cluster_name} (CZID #321)"
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  permissions_boundary = var.permissions_boundary_arn
  tags                 = var.tags
}

resource "aws_iam_policy" "this" {
  name        = "${var.cluster_name}-aws-load-balancer-controller"
  description = "AWS Load Balancer Controller permissions for ${var.cluster_name} (CZID #321)"
  policy      = file("${path.module}/iam-policy.json")
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}
