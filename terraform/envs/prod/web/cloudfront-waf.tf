# CZID-356 (#356): CLOUDFRONT-scoped WAF for this env's CloudFront distribution(s). Attached via
# web_acl_id in assets.tf. Distinct from the REGIONAL ALB ACL in envs/prod/web-waf (scope mismatch —
# see modules/cloudfront-web-acl/README.md). count_only = true bakes the managed rules in COUNT first;
# ops flips to false to enforce after the CloudWatch observability bake. AWS-gated (no apply here).
module "cloudfront_waf" {
  source     = "../../../modules/cloudfront-web-acl"
  tags       = var.tags # TODO: var.tags is deprecated
  count_only = true

  # CLOUDFRONT-scoped ACLs must be created in us-east-1 (same aliased provider the ACM cert uses).
  providers = {
    aws = aws.us-east-1
  }
}
