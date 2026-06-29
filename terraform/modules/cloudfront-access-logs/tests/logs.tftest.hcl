# CZID-161 pattern — offline module unit test for the CloudFront access-log bucket.
mock_provider "aws" {}

run "log_bucket_hardened" {
  command = plan

  variables {
    env = "prod"
  }

  assert {
    condition     = aws_s3_bucket.logs.bucket == "seqtoid-prod-cloudfront-logs"
    error_message = "log bucket name must be <name_prefix>-<env>-cloudfront-logs"
  }
  assert {
    condition     = aws_s3_bucket_public_access_block.logs.block_public_acls == true && aws_s3_bucket_public_access_block.logs.restrict_public_buckets == true
    error_message = "public access must be fully blocked"
  }
  assert {
    condition     = aws_s3_bucket_versioning.logs.versioning_configuration[0].status == "Enabled"
    error_message = "versioning must be enabled"
  }
}
