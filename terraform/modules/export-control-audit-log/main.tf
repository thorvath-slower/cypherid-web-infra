# CZID-331 — immutable, retained audit-log store for the export-control evidence trail (epic CZID-321).
#
# Every access decision (WAF verdicts + the Layer-2 edge Lambda's per-request decisions) is the compliance
# evidence that the controls operated. This module is the tamper-proof destination: an S3 bucket with
# Object Lock in COMPLIANCE mode + versioning, so records cannot be deleted or altered within the
# counsel-defined retention window — not even by root.
#
# Why a dedicated bucket: Object Lock can only be enabled at BUCKET CREATION (object_lock_enabled = true),
# which the vendored cztack aws-s3-private-bucket module (used for the existing WAF logs) does not expose.
#
# AWS-GATED (bucket-b): nothing is applied. Standing this up + repointing the WAF logging at it is a
# DESTRUCTIVE migration of the existing log bucket — see the README + EXPORT-CONTROL-BUCKET-B-OUTLINE.md.

data "aws_caller_identity" "current" {}

locals {
  # aws-waf-logs- prefix is required for WAF to deliver to the bucket directly.
  bucket_name = substr("aws-waf-logs-${var.name}-${data.aws_caller_identity.current.account_id}", 0, 63)
}

resource "aws_s3_bucket" "audit" {
  bucket              = local.bucket_name
  object_lock_enabled = true # creation-time only — the whole reason this is a dedicated bucket
  tags                = var.tags
}

# Object Lock requires versioning.
resource "aws_s3_bucket_versioning" "audit" {
  bucket = aws_s3_bucket.audit.id
  versioning_configuration {
    status = "Enabled"
  }
}

# COMPLIANCE-mode default retention — immutable for the record-keeping window (counsel-owned days).
resource "aws_s3_bucket_object_lock_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id
  rule {
    default_retention {
      mode = var.object_lock_mode
      days = var.retention_days
    }
  }
  depends_on = [aws_s3_bucket_versioning.audit]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id
  rule {
    bucket_key_enabled = var.kms_key_arn != ""
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn != "" ? var.kms_key_arn : null
    }
  }
}

resource "aws_s3_bucket_public_access_block" "audit" {
  bucket                  = aws_s3_bucket.audit.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy: TLS-only, and let AWS log delivery write WAF logs (mirrors the existing WAF-log policy).
data "aws_iam_policy_document" "audit" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.audit.arn, "${aws_s3_bucket.audit.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid       = "AllowWAFLogDeliveryWrite"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.audit.arn}/AWSLogs/*"]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid       = "AllowWAFLogDeliveryAclRead"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.audit.arn]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "audit" {
  bucket = aws_s3_bucket.audit.id
  policy = data.aws_iam_policy_document.audit.json
}

# --- Optional: Firehose to centralize the Layer-2 edge Lambda decision logs into this immutable store ---
# Lambda@Edge logs land in CloudWatch per edge-region; the consuming stack adds a per-region subscription
# filter (reason="...") → this Firehose → the bucket. See the README for the wiring.
data "aws_iam_policy_document" "firehose_assume" {
  count = var.create_edge_log_firehose ? 1 : 0
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "firehose" {
  count              = var.create_edge_log_firehose ? 1 : 0
  name               = "${var.name}-edge-audit-firehose"
  assume_role_policy = data.aws_iam_policy_document.firehose_assume[0].json
  tags               = var.tags
}

data "aws_iam_policy_document" "firehose" {
  count = var.create_edge_log_firehose ? 1 : 0
  statement {
    effect    = "Allow"
    actions   = ["s3:AbortMultipartUpload", "s3:GetBucketLocation", "s3:GetObject", "s3:ListBucket", "s3:ListBucketMultipartUploads", "s3:PutObject"]
    resources = [aws_s3_bucket.audit.arn, "${aws_s3_bucket.audit.arn}/*"]
  }
  dynamic "statement" {
    for_each = var.kms_key_arn != "" ? [1] : []
    content {
      effect    = "Allow"
      actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
      resources = [var.kms_key_arn]
    }
  }
}

resource "aws_iam_role_policy" "firehose" {
  count  = var.create_edge_log_firehose ? 1 : 0
  name   = "edge-audit-firehose"
  role   = aws_iam_role.firehose[0].id
  policy = data.aws_iam_policy_document.firehose[0].json
}

resource "aws_kinesis_firehose_delivery_stream" "edge_logs" {
  count       = var.create_edge_log_firehose ? 1 : 0
  name        = "${var.name}-edge-audit"
  destination = "extended_s3"
  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose[0].arn
    bucket_arn          = aws_s3_bucket.audit.arn
    prefix              = "edge-decisions/"
    error_output_prefix = "edge-decisions-errors/"
    compression_format  = "GZIP"
    buffering_size      = 5
    buffering_interval  = 300
  }
  tags = var.tags
}
