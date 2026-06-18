locals {
  orgwide_secrets_policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${module.orgwide-secrets-policy.policy_name}"
}

data "aws_caller_identity" "current" {}

module "orgwide-secrets-policy" {
  source = "../aws-iam-policy-document-orgwide-secrets"
}

resource "aws_iam_role_policy_attachment" "orgwide-secrets-policy" {
  role       = var.role_name
  policy_arn = local.orgwide_secrets_policy_arn
}
