# CZID-59 — ECR image-layer encryption hardening for the idseq-web repository
# (aws_ecr_repository.web-repository in main.tf). Mirrors the RDS pattern in
# db/aurora_hardening.tf: a customer-managed KMS key (CMK), greenfield-gated.
#
# ⚠️ REPLACE-ON-APPLY HAZARD: an ECR repository's encryption_configuration is
# IMMUTABLE — AWS cannot re-encrypt an existing repo in place, so turning KMS on
# for a repo that already exists forces terraform to DESTROY and RECREATE it
# (all image layers must be re-pushed). Hence the greenfield gate: the CMK + the
# encryption_configuration are created ONLY where var.manage_ecr_kms_cmk = true.
# On live envs it stays false → local.ecr_kms_key_arn is null → the repo keeps
# the AWS-owned key with NO change / no replacement. Flip the var per-env at
# apply time as an explicit ops decision (a fresh account, or a scheduled
# re-encrypt window where re-pushing the image is acceptable).
#
# Canonical + mirrored across dev/staging/prod/sandbox (SSOT); var.manage_ecr_kms_cmk
# is the only greenfield-vs-live difference. Uses the existing
# data.aws_caller_identity.current declared in main.tf.

locals {
  # CMK ARN when managed (greenfield), else null so the repo falls back to the
  # AWS-owned key with no change on live envs. Immutable, hence the greenfield gate.
  ecr_kms_key_arn = var.manage_ecr_kms_cmk ? aws_kms_key.ecr[0].arn : null
}

# --- Customer-managed KMS key for ECR image layers (CKV_AWS_136) -------------------------------
# CKV2_AWS_64: declare an explicit key policy. Grants the account root full admin — the
# AWS-recommended anti-lockout baseline that lets IAM policies govern actual key use. Equivalent
# to the implicit default policy, but declared so it is auditable (checkov requires an explicit one).
data "aws_iam_policy_document" "ecr_kms" {
  # This is a KMS *key* policy, not an IAM identity policy. The single root-admin statement is AWS's
  # mandatory anti-lockout pattern (kms:* on the key). The following IAM-identity-policy checks are
  # false positives here: a key policy's resource is implicitly the key itself, and root admin must
  # be unconstrained or the key becomes unmanageable.
  # checkov:skip=CKV_AWS_109:root-admin on a KMS key policy is required to keep the key manageable
  # checkov:skip=CKV_AWS_111:root-admin on a KMS key policy is intentionally unconstrained (anti-lockout)
  # checkov:skip=CKV_AWS_356:a KMS key policy scopes to its own key; "*" is the only valid resource here
  statement {
    sid       = "EnableRootAccountAdmin"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_kms_key" "ecr" {
  count                   = var.manage_ecr_kms_cmk ? 1 : 0
  description             = "seqtoid ECR image layers (${var.env})"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.ecr_kms.json

  tags = {
    terraform = true
  }
}

resource "aws_kms_alias" "ecr" {
  count         = var.manage_ecr_kms_cmk ? 1 : 0
  name          = "alias/seqtoid-ecr-${var.env}"
  target_key_id = aws_kms_key.ecr[0].key_id
}
