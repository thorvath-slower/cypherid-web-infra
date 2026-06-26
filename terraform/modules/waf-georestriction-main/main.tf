locals {
  rule_group_name = "${var.tags.project}-${var.tags.env}-${var.tags.service}-geoblocking"
}

resource "aws_wafv2_rule_group" "geo_restriction" {
  name        = local.rule_group_name
  description = "WAF rule group to block countries in the geoblocking list."
  scope       = var.scope
  capacity    = 10

  rule {
    name     = "block-geoblocked-countries"
    priority = 1
    action {
      block {}
    }
    statement {
      geo_match_statement {
        # CZID-323: US export-embargoed jurisdictions. The AUTHORITATIVE, versioned list is owned by
        # compliance/counsel (CZID-322) — this is the engineering enforced baseline, kept as config.
        # UA = all of Ukraine: WAF geo-match is country-granular and cannot match the Crimea/DNR/LNR
        # regions alone, so region precision is handled by Layer 2 IP-intel (CZID-327).
        # RU added per Tom's directive (2026-06-25); pending counsel ratification — a program-specific
        # sanction, not a comprehensive embargo, so the all-Russia over-block carries business impact.
        country_codes = ["CU", "IR", "KP", "RU", "SY", "UA"]
      }
    }
    visibility_config {
      sampled_requests_enabled   = var.enable_visibility
      cloudwatch_metrics_enabled = var.enable_visibility
      metric_name                = "block-geoblocked-countries"
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = var.enable_visibility
    metric_name                = local.rule_group_name
    sampled_requests_enabled   = var.enable_visibility
  }
}
