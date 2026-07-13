# cloudfront-access-logs

A private S3 bucket configured to receive **CloudFront standard (legacy) access logs** (CZID-61 / #61),
so a distribution's `logging_config` satisfies checkov `CKV_AWS_86` (access logging enabled).

## What it does

- Creates a private bucket (via `aws-s3-private-bucket-v0.104.2`) named
  `cloudfront-access-logs-<project>-<env>-<service>-<account_id>` (deterministic, globally unique —
  no hardcoded/ops-gated name).
- Enables ACLs (`object_ownership = BucketOwnerPreferred`) and grants **FULL_CONTROL** to the
  CloudFront `awslogsdelivery` canonical user + the bucket owner — required for standard logging.
- Adds a lifecycle rule expiring logs after `log_retention_days` (default 365).

## Usage

```hcl
module "access_logs" {
  source = "../../../modules/cloudfront-access-logs"
  tags   = var.tags
}

resource "aws_cloudfront_distribution" "distribution" {
  # ...
  logging_config {
    bucket          = module.access_logs.bucket_domain_name
    include_cookies = false
    prefix          = "assets/"
  }
}
```

## Notes / follow-ups

- Uses **standard** CloudFront logging (the mechanism the existing `logging_config` argument drives).
  The newer log-delivery-service / real-time flow is a separate, larger change and out of scope for
  this hardening slice.
- Bucket lives in the stack's default region. AWS-gated — no apply is performed by this PR.
