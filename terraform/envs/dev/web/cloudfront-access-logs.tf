# CZID-61 (#61): private S3 bucket for CloudFront standard access logs (CKV_AWS_86). Referenced by the
# distribution's logging_config in assets.tf. Bucket name is account-derived (deterministic, no
# hardcoded name). AWS-gated: no apply here.
module "cloudfront_access_logs" {
  source = "../../../modules/cloudfront-access-logs"
  tags   = var.tags # TODO: var.tags is deprecated
}
