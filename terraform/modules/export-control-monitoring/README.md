# `export-control-monitoring` — CZID-332

Monitoring + alerting for the export-control enforcement controls. Surfaces, alarms, and dashboards the
signals the compliance posture needs visible and paged. **Authored, not applied** (bucket-b) — apply is gated
on Tom + compliance; recipients/thresholds are tuned by on-call.

## What it watches

| Signal | Source | Why it matters |
|---|---|---|
| **Blocked-jurisdiction attempts** | geo-block rule (CZID-323) | the headline export-control signal — direct access from a sanctioned jurisdiction. Threshold is deliberately low. |
| **Anonymizer hits** | AnonymousIpList rule (CZID-324) | VPN/proxy/Tor/hosting denials — evasion surge, or a corporate/CI range to allowlist |
| **Total WAF blocks** | the web ACL | broad anomaly / false-positive surge |
| **Fail-closed denials** | Layer-2 edge Lambda (CZID-330) | provider degraded → we're denying *legitimate* users; page on-call |

Each fans out to an SNS topic; an optional CloudWatch dashboard summarizes all four.

## Usage

```hcl
module "export_control_monitoring" {
  source = "../../modules/export-control-monitoring"

  # SSOT: every name is wired from the module that defines it — none are re-typed here.
  web_acl_name           = module.web-service-waf.web_acl_name
  anonymizer_metric_name = module.web-service-waf.rule_metric_names.anonymous_ip
  geo_block_metric_name  = "${module.georestriction-rule.name}-metrics" # geo rule-group name + the web-acl "-metrics" suffix
  region                 = "us-west-2"
  alert_emails           = var.export_control_alert_emails # compliance-owned — pass from the env, don't hard-code

  fail_closed_log_group_name = "" # optional Layer-2 fail-closed alarm — see note below

  tags = local.tags
}
```

## Notes

- **`geo_block_metric_name`** has no default — it depends on the deployed geo rule-group name. Read it from the
  `web-acl` / `waf-georestriction-main` outputs or set it explicitly.
- **Lambda@Edge fail-closed alarm:** Lambda@Edge writes logs to `/aws/lambda/<edge-region>.<function>` in **each**
  region it executes, so there is no single log group. Either (a) aggregate the edge logs into one group and point
  `fail_closed_log_group_name` at it, or (b) instantiate this module's metric-filter per region in the consuming
  stack. Left empty, the fail-closed alarm is simply not created.
- **Recipients are compliance-owned (CZID-334).** `alert_emails` defaults to empty; wire real addresses from the
  env stack. The topic still exists so alarms have a target.
- Thresholds default to conservative starting points — tune during the `count_only` canary (CZID-323/324) as real
  traffic volumes become known.
