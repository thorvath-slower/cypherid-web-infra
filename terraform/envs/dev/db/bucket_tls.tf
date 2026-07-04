# CZID-60 — TLS-only (encryption-in-transit) bucket policies for the sample-data
# buckets (aws_s3_bucket.samples / .samples_v1 in bucket.tf). Denies every request
# made over plaintext HTTP (aws:SecureTransport = false).
#
# In-place safe: attaching a bucket POLICY does not replace the bucket and does not
# touch object data. The policy only denies non-TLS access, so existing HTTPS
# clients (the app, presigned links, CORS callers) are unaffected. Both buckets set
# block_public_policy = true (see bucket.tf); a SecureTransport Deny is not a "public"
# statement, so it applies cleanly under the public-access block.
#
# Canonical + mirrored across dev/staging/prod/sandbox (SSOT).

data "aws_iam_policy_document" "samples_tls" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.samples.arn,
      "${aws_s3_bucket.samples.arn}/*",
    ]
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
}

resource "aws_s3_bucket_policy" "samples_tls" {
  bucket = aws_s3_bucket.samples.id
  policy = data.aws_iam_policy_document.samples_tls.json
}

data "aws_iam_policy_document" "samples_v1_tls" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.samples_v1.arn,
      "${aws_s3_bucket.samples_v1.arn}/*",
    ]
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
}

resource "aws_s3_bucket_policy" "samples_v1_tls" {
  bucket = aws_s3_bucket.samples_v1.id
  policy = data.aws_iam_policy_document.samples_v1_tls.json
}
