# CZID-354 / CZID-365 (SSOT) — shared CloudFront access-log bucket, instantiated (not copied per-env).
# Each distribution below references module.cloudfront_logs.bucket_domain_name in its logging_config.
module "cloudfront_logs" {
  source = "../../../modules/cloudfront-access-logs"
  env    = var.env
}
