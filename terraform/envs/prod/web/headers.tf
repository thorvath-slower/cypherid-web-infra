# CZID-355 — CloudFront security response-headers policy (prod web distributions).
# Attached to every cache behavior of the assets / czid-assets / redirect distributions (clears
# CKV2_AWS_32). Conservative, reversible defaults — HSTS includeSubdomains but NO preload (preload is
# a deliberate, hard-to-undo browser-list submission); the sites are already HTTPS (redirect-to-https).
resource "aws_cloudfront_response_headers_policy" "security" {
  name    = "seqtoid-${var.env}-security-headers"
  comment = "Security response headers for the prod web CloudFront distributions (CZID-355)"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000 # 1 year
      include_subdomains         = true
      preload                    = false
      override                   = true
    }
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }
}
