# CZID-355 / CZID-365 (SSOT) — instantiate the shared CloudFront security-headers module instead of
# defining the policy inline per env. dev/staging/maintenance/zendesk reuse the SAME module (one
# definition, no per-env copies). Attached to the distributions via module.security_headers.policy_id.
module "security_headers" {
  source = "../../../modules/cloudfront-security-headers"
  env    = var.env
}
