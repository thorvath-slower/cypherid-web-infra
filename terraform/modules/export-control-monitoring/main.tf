# CZID-332 — monitoring + alerting for the export-control enforcement controls.
#
# Surfaces the signals the compliance posture needs visible + paged:
#   - blocked-jurisdiction attempts   (geo-block rule, CZID-323) — the headline export-control signal
#   - anonymizer hits                 (AnonymousIpList rule, CZID-324) — the evasion-channel denial
#   - total WAF blocks                — broad anomaly / false-positive surge
#   - fail-closed denials             (Layer-2 edge Lambda, CZID-330) — provider degraded, denying legit users
#
# Authored, NOT applied (bucket-b). Alert recipients + thresholds are tuned by compliance/on-call.

locals {
  name_prefix = "export-control-${lookup(var.tags, "env", "unknown")}"
}

# --- Alert fan-out. Recipients owned by the compliance office (CZID-334); wired via var.alert_emails. ---
resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  for_each  = toset(var.alert_emails)
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

# --- Layer-1 WAF alarms (AWS/WAFV2; single region for the regional WAF) ---

# Blocked-jurisdiction attempts — the headline export-control signal. Threshold is deliberately low:
# a sustained signal means a sanctioned-jurisdiction origin is hitting us directly (geo-block, CZID-323).
resource "aws_cloudwatch_metric_alarm" "blocked_jurisdiction" {
  alarm_name          = "${local.name_prefix}-blocked-jurisdiction-attempts"
  alarm_description   = "Direct access attempts from a blocked jurisdiction were denied (geo-block, CZID-323). Review for export-control reporting + the IR runbook (CZID-334)."
  namespace           = "AWS/WAFV2"
  metric_name         = "BlockedRequests"
  dimensions          = { WebACL = var.web_acl_name, Region = var.region, Rule = var.geo_block_metric_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.blocked_jurisdiction_alarm_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  tags                = var.tags
}

# Anonymizer (VPN/proxy/Tor/hosting) hits — the evasion-channel denial (CZID-324).
resource "aws_cloudwatch_metric_alarm" "anonymizer_hits" {
  alarm_name          = "${local.name_prefix}-anonymizer-hits"
  alarm_description   = "Elevated VPN/proxy/Tor/hosting traffic blocked by AnonymousIpList (CZID-324) — possible evasion surge or a misclassified corporate/CI range to allowlist."
  namespace           = "AWS/WAFV2"
  metric_name         = "BlockedRequests"
  dimensions          = { WebACL = var.web_acl_name, Region = var.region, Rule = var.anonymizer_metric_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.anonymizer_alarm_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  tags                = var.tags
}

# Total WAF blocks — broad anomaly signal (bypass attempt or false-positive surge).
resource "aws_cloudwatch_metric_alarm" "total_blocked_spike" {
  alarm_name          = "${local.name_prefix}-waf-blocked-spike"
  alarm_description   = "Spike in total WAF-blocked requests — investigate for a bypass attempt or a false-positive surge."
  namespace           = "AWS/WAFV2"
  metric_name         = "BlockedRequests"
  dimensions          = { WebACL = var.web_acl_name, Region = var.region }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.total_blocked_alarm_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  tags                = var.tags
}

# --- Layer-2 edge Lambda fail-closed (CZID-330) ---
# When the IP-intel provider errors/times out, the Lambda fails closed (denies, reason="provider_error").
# A spike means the provider is degraded and we're denying legitimate users — page on-call. Optional:
# needs the edge Lambda log group (Lambda@Edge logs per edge-region — see README).
resource "aws_cloudwatch_log_metric_filter" "fail_closed" {
  count          = var.fail_closed_log_group_name == "" ? 0 : 1
  name           = "${local.name_prefix}-fail-closed"
  log_group_name = var.fail_closed_log_group_name
  pattern        = "{ $.reason = \"provider_error\" }"

  metric_transformation {
    name          = "FailClosedDenials"
    namespace     = "ExportControl"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "fail_closed" {
  count               = var.fail_closed_log_group_name == "" ? 0 : 1
  alarm_name          = "${local.name_prefix}-fail-closed-denials"
  alarm_description   = "Layer-2 edge is failing closed (denying on provider error/timeout, CZID-330). The IP-intel provider is likely degraded — legitimate users are being denied. Page on-call."
  namespace           = "ExportControl"
  metric_name         = "FailClosedDenials"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.fail_closed_alarm_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  tags                = var.tags
}

# --- Dashboard ---
resource "aws_cloudwatch_dashboard" "export_control" {
  count          = var.create_dashboard ? 1 : 0
  dashboard_name = "${local.name_prefix}-enforcement"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6,
        properties = {
          title   = "Blocked-jurisdiction attempts (geo, CZID-323)"
          region  = var.region
          stat    = "Sum"
          period  = 300
          metrics = [["AWS/WAFV2", "BlockedRequests", "WebACL", var.web_acl_name, "Region", var.region, "Rule", var.geo_block_metric_name]]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6,
        properties = {
          title   = "Anonymizer hits (VPN/proxy/Tor, CZID-324)"
          region  = var.region
          stat    = "Sum"
          period  = 300
          metrics = [["AWS/WAFV2", "BlockedRequests", "WebACL", var.web_acl_name, "Region", var.region, "Rule", var.anonymizer_metric_name]]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6,
        properties = {
          title  = "Total WAF blocked vs allowed"
          region = var.region
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/WAFV2", "BlockedRequests", "WebACL", var.web_acl_name, "Region", var.region],
            ["AWS/WAFV2", "AllowedRequests", "WebACL", var.web_acl_name, "Region", var.region]
          ]
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6,
        properties = {
          title   = "Fail-closed denials (Layer-2 provider degraded, CZID-330)"
          region  = var.region
          stat    = "Sum"
          period  = 300
          metrics = [["ExportControl", "FailClosedDenials"]]
        }
      }
    ]
  })
}
