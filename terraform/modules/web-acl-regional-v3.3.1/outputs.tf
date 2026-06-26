output "web_acl_arn" {
  value       = aws_wafv2_web_acl.main.arn
  description = "The ACL's ARN. This value should be attached to your application [Distribution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution#web_acl_id)"
}

output "web_acl_id" {
  value       = aws_wafv2_web_acl.main.id
  description = "The ACL's ID"
}

output "web_acl_name" {
  value       = aws_wafv2_web_acl.main.name
  description = "The web ACL name — the CloudWatch WebACL dimension the monitoring module alarms on (single source)."
}

output "scope" {
  value       = "REGIONAL"
  description = "The ACL scope. It can be REGIONAL or CLOUDFRONT"
}

output "panther-role" {
  value = var.enable_panther_ingest ? {
    "arn" : module.panther-s3[0].role.arn,
    "name" : module.panther-s3[0].role.name,
    "kms_key_id" : module.panther-s3[0].kms_id,
    } : {
    "arn" : "not configured",
    "name" : "not configured",
    "kms_key_id" : "not configured",
  }
  description = "This role helps CZI's SecEng Team measure the effectiveness of the ACL. Ask #help-infosec in CZI Slack if you have questions."
}

output "web_acl_log_bucket" {
  value = {
    "bucket" : module.logs_bucket.name,
    "arn" : module.logs_bucket.arn,
    "account_id" : local.account_id,
  }
  description = "Your team can find the WebACL Logs at this bucket. The files will be formatted according to [this guide](https://docs.aws.amazon.com/waf/latest/developerguide/logging-s3.html#:~:text=your%20account%20ID.-,Naming%20requirements%20and%20syntax,-Your%20bucket%20names)."
}

# CZID-332: expose each export-control rule's CloudWatch metric_name so the monitoring/alerting module
# consumes them from HERE (the single source) instead of re-typing the literals — they cannot drift
# from the web ACL that emits them.
output "rule_metric_names" {
  value = {
    anonymous_ip  = local.anonymous_ip_rulename
    ip_reputation = local.ip_reputation_rulename
    rate_limit    = local.many_requests_rulename
  }
  description = "CloudWatch metric_name of each export-control rule (anonymizer, IP-reputation, rate-limit), for the monitoring module to alarm on."
}
