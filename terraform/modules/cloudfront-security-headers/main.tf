# CZID-355 / CZID-365 (SSOT) — shared CloudFront security response-headers policy.
# ONE definition, instantiated by each env/stack that fronts the app with CloudFront (web /
# maintenance / zendesk, all envs) — so the policy is never copied per-env. Conservative, reversible
# defaults (HSTS includeSubdomains but NO preload — preload is a hard-to-undo browser-list submission;
# the sites are already HTTPS via redirect-to-https). Override knobs are exposed for env differences.
resource "aws_cloudfront_response_headers_policy" "this" {
  name    = "${var.name_prefix}-${var.env}-security-headers"
  comment = "Security response headers for ${var.name_prefix} ${var.env} CloudFront (CZID-355)"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = var.hsts_max_age_sec
      include_subdomains         = var.hsts_include_subdomains
      preload                    = var.hsts_preload
      override                   = true
    }
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = var.frame_option
      override     = true
    }
    referrer_policy {
      referrer_policy = var.referrer_policy
      override        = true
    }
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }
}
