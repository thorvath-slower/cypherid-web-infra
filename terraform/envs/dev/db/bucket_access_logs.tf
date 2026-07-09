# --- S3 server access logging for the samples buckets (CZID-343) ---
# Mirrors the merged aegea-ecs-execute access-logging pattern (ecs stack, #21):
# a dedicated log-destination bucket + a bucket policy granting the S3 logging
# service PutObject, then an aws_s3_bucket_logging on each private samples
# bucket. Additive and apply-safe (new resources + a logging attachment; the
# existing samples/samples_v1 buckets are not recreated). Closes CKV_AWS_18 on
# the two private db buckets. data.aws_caller_identity.current is already
# declared in aurora_hardening.tf and reused here.

resource "aws_s3_bucket" "samples_access_logs" {
  #checkov:skip=CKV_AWS_145:S3 access-log delivery is unsupported with the aws/s3 managed KMS key; AES256 is the supported at-rest option for log destinations
  #checkov:skip=CKV_AWS_18:a log-destination bucket does not log to itself (would recurse)
  #checkov:skip=CKV_AWS_144:cross-region replication is not warranted for short-lived access logs
  #checkov:skip=CKV2_AWS_62:no event-notification consumer for access logs
  bucket        = "samples-s3-access-logs-${var.env}-${data.aws_caller_identity.current.account_id}"
  force_destroy = contains(["dev", "sandbox"], var.env)
  tags          = { terraform = true }
}

resource "aws_s3_bucket_public_access_block" "samples_access_logs" {
  bucket                  = aws_s3_bucket.samples_access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "samples_access_logs" {
  bucket = aws_s3_bucket.samples_access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "samples_access_logs" {
  bucket = aws_s3_bucket.samples_access_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "samples_access_logs" {
  bucket = aws_s3_bucket.samples_access_logs.id
  rule {
    id     = "expire-access-logs"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_policy" "samples_access_logs" {
  bucket = aws_s3_bucket.samples_access_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "S3ServerAccessLogsPolicy"
      Effect    = "Allow"
      Principal = { Service = "logging.s3.amazonaws.com" }
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.samples_access_logs.arn}/*"
      Condition = {
        ArnLike = { "aws:SourceArn" = [
          aws_s3_bucket.samples.arn,
          aws_s3_bucket.samples_v1.arn,
        ] }
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })
}

resource "aws_s3_bucket_logging" "samples" {
  bucket        = aws_s3_bucket.samples.id
  target_bucket = aws_s3_bucket.samples_access_logs.id
  target_prefix = "samples/"
}

resource "aws_s3_bucket_logging" "samples_v1" {
  bucket        = aws_s3_bucket.samples_v1.id
  target_bucket = aws_s3_bucket.samples_access_logs.id
  target_prefix = "samples_v1/"
}
