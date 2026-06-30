# CZID-354 / CZID-365 (SSOT) — shared CloudFront access-log delivery bucket.
# ONE hardened log bucket per stack, instantiated (not copied) by each CloudFront stack that turns on
# logging_config. Carries the CloudFront-specific gotchas in one place:
#   - Object Ownership = BucketOwnerPreferred (ACLs ENABLED) + the awslogsdelivery ACL grant — CloudFront
#     STANDARD (legacy) logging writes via that S3 ACL; BucketOwnerEnforced (ACLs off) would break it.
#   - SSE = AES256, NOT KMS — CloudFront log delivery does not support SSE-KMS (would silently drop logs).
# Public access is fully blocked; the grant is to a specific AWS canonical user, not "public".

data "aws_canonical_user_id" "current" {}

resource "aws_s3_bucket" "logs" {
  # checkov:skip=CKV_AWS_145:CloudFront standard log delivery does not support SSE-KMS; AES256 is required (set below).
  # checkov:skip=CKV_AWS_18:This IS the access-log bucket — logging it to itself would be circular.
  # checkov:skip=CKV_AWS_144:Cross-region replication is unnecessary for ephemeral CloudFront logs (expired at retention_days).
  # checkov:skip=CKV2_AWS_62:Event notifications are not needed for a CloudFront log sink.
  bucket = "${var.name_prefix}-${var.env}-cloudfront-logs"
  tags   = var.tags
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  # checkov:skip=CKV2_AWS_65:ACLs must remain ENABLED (BucketOwnerPreferred) — CloudFront standard logging writes via the awslogsdelivery ACL grant.
  bucket = aws_s3_bucket.logs.id
  rule {
    object_ownership = "BucketOwnerPreferred" # ACLs enabled — required for CloudFront standard logging
  }
}

resource "aws_s3_bucket_acl" "logs" {
  depends_on = [aws_s3_bucket_ownership_controls.logs]
  bucket     = aws_s3_bucket.logs.id
  access_control_policy {
    owner {
      id = data.aws_canonical_user_id.current.id
    }
    grant {
      grantee {
        type = "CanonicalUser"
        id   = data.aws_canonical_user_id.current.id
      }
      permission = "FULL_CONTROL"
    }
    grant {
      # The CloudFront log-delivery account (awslogsdelivery) canonical user id (global, AWS-published).
      grantee {
        type = "CanonicalUser"
        id   = "c4c1ede66af53448b93c283ce9448c4ba468c9432aa01d700d3878632f77d2d0"
      }
      permission = "FULL_CONTROL"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # CloudFront log delivery does not support SSE-KMS
    }
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  depends_on = [aws_s3_bucket_versioning.logs]
  bucket     = aws_s3_bucket.logs.id
  rule {
    id     = "expire-cloudfront-logs"
    status = "Enabled"
    filter {}
    expiration {
      days = var.retention_days
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
