
locals {
  # SINGLE SOURCE for the export-control blocked-jurisdiction list (CZID-322) — the SAME file the
  # Layer-2 Lambda bundles via build.sh. Change the list there, never here.
  blocked_country_codes = jsondecode(file("${path.module}/../../../export-control/blocked-jurisdictions.json")).blocked_country_codes
  # Counsel-owned audit retention (CZID-331), single source — see export-control/audit-config.json.
  audit_log_retention_days = jsondecode(file("${path.module}/../../../export-control/audit-config.json")).audit_log_retention_days
}

# CZID-331 — the dedicated, immutable export-control evidence store, SEPARATE from the normal WAF/app log
# bucket. Authored + plan-ready; apply is bucket-b. Retention is the counsel-set value above.
module "export_control_audit_log" {
  source                   = "../../../modules/export-control-audit-log"
  name                     = "${var.tags.project}-${var.tags.env}-export-control"
  retention_days           = local.audit_log_retention_days
  create_edge_log_firehose = true
  tags                     = var.tags
}

module "georestriction-rule" {
  # tflint-ignore: terraform_module_pinned_source
  source = "../../../modules/waf-georestriction-main"

  scope                 = "REGIONAL"
  blocked_country_codes = local.blocked_country_codes
  tags                  = var.tags # TODO: var.tags is deprecated
}

module "web-service-waf" {
  source                = "../../../modules/web-acl-regional-v3.3.1"
  tags                  = var.tags # TODO: var.tags is deprecated
  rule_groups           = [{ arn : module.georestriction-rule.arn, name : module.georestriction-rule.name }]
  enable_panther_ingest = false
  czi_baseline_count_rules = {
    CommonRuleSet = [
      "NoUserAgent_HEADER",
      "UserAgent_BadBots_HEADER",
      "SizeRestrictions_QUERYSTRING",
      "SizeRestrictions_Cookie_HEADER",
      "SizeRestrictions_URIPATH",
      "EC2MetaDataSSRF_BODY",
      "EC2MetaDataSSRF_COOKIE",
      "EC2MetaDataSSRF_URIPATH",
      "EC2MetaDataSSRF_QUERYARGUMENTS",
      "GenericLFI_QUERYARGUMENTS",
      "GenericLFI_URIPATH",
      "GenericLFI_BODY",
      "RestrictedExtensions_URIPATH",
      "RestrictedExtensions_QUERYARGUMENTS",
      "GenericRFI_QUERYARGUMENTS",
      "GenericRFI_BODY",
      "GenericRFI_URIPATH",
      "CrossSiteScripting_COOKIE",
      "CrossSiteScripting_BODY"
    ]
    KnownBadInputsRuleSet = [
      "JavaDeserializationRCE_BODY",
      "JavaDeserializationRCE_URIPATH",
      "JavaDeserializationRCE_QUERYSTRING",
      "JavaDeserializationRCE_HEADER",
      "Host_localhost_HEADER",
      "PROPFIND_METHOD",
      "ExploitablePaths_URIPATH",
      "Log4JRCE_BODY",
      "Log4JRCE_HEADER"
    ]
    SQLiRuleSet = [
      "SQLiExtendedPatterns_QUERYARGUMENTS",
      "SQLi_QUERYARGUMENTS",
      "SQLi_BODY",
      "SQLi_COOKIE",
      "SQLi_URIPATH",
      "SQLiExtendedPatterns_BODY",
    ]
  }
}

# module "snowflake-ingest" {
#   source        = "git@github.com:chanzuckerberg/shared-infra//terraform/modules/snowflake-stage-s3-role?ref=v0.420.0"
#   project       = var.project
#   env           = var.env
#   service       = var.component
#   owner         = var.owner
#   bucket_name   = module.web-service-waf.web_acl_log_bucket.bucket
#   bucket_prefix = "/AWSLogs"

#   aws_iam_principal = var.snowflake_iam_principal // Defined in Terraform Workplace settings in TFE
#   external_ids      = var.snowflake_external_ids
# }

resource "aws_wafv2_web_acl_association" "web" {
  resource_arn = local.alb_arn
  web_acl_arn  = module.web-service-waf.web_acl_arn
}
