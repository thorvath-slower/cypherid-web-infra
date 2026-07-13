# CZID-161 — IaC module unit test (Terraform native `terraform test`), fully offline via mock_provider.
# Establishes the module-test pattern for the infra repos (the test layer the strategy calls for):
# a module ships with a plan-time test asserting its security-relevant defaults + override behavior.
# Run: `terraform test` from the module dir (no AWS creds needed — the aws provider is mocked).

mock_provider "aws" {}

run "secure_defaults" {
  command = plan

  variables {
    env = "prod"
  }

  assert {
    condition     = aws_cloudfront_response_headers_policy.this.name == "seqtoid-prod-security-headers"
    error_message = "policy name must be <name_prefix>-<env>-security-headers"
  }
  assert {
    condition     = aws_cloudfront_response_headers_policy.this.security_headers_config[0].strict_transport_security[0].include_subdomains == true
    error_message = "HSTS must include subdomains by default"
  }
  assert {
    condition     = aws_cloudfront_response_headers_policy.this.security_headers_config[0].strict_transport_security[0].preload == false
    error_message = "HSTS preload must default to false (preload is a hard-to-undo browser-list submission)"
  }
  assert {
    condition     = aws_cloudfront_response_headers_policy.this.security_headers_config[0].frame_options[0].frame_option == "DENY"
    error_message = "X-Frame-Options must default to DENY"
  }
  assert {
    condition     = aws_cloudfront_response_headers_policy.this.security_headers_config[0].content_type_options[0].override == true
    error_message = "X-Content-Type-Options (nosniff) must be set"
  }
}

run "preload_is_overridable" {
  command = plan

  variables {
    env          = "prod"
    hsts_preload = true
  }

  assert {
    condition     = aws_cloudfront_response_headers_policy.this.security_headers_config[0].strict_transport_security[0].preload == true
    error_message = "hsts_preload must be overridable for envs that opt in"
  }
}
