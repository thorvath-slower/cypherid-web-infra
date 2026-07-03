# cloudfront-web-acl

A **CLOUDFRONT-scoped** WAFv2 Web ACL for the platform's CloudFront distributions (CZID-356 / #356).

## Why this exists (and is separate from `web-acl-regional-v3.3.1`)

CloudFront requires a Web ACL with `scope = CLOUDFRONT` created in **us-east-1** (a *global* ACL).
That is a **distinct resource** from the **REGIONAL** ALB ACL in `web-acl-regional-v3.3.1` /
`envs/*/web-waf` (the export-control geo/anonymizer stack, #280/#281/#282). A REGIONAL ACL ARN
**cannot** be attached to a CloudFront distribution — the scope mismatch is an apply error — so this
module is not a reuse of that ACL.

## What it does

Creates a CLOUDFRONT-scoped ACL with the AWS-managed baseline rule groups:

- `AWSManagedRulesCommonRuleSet` (OWASP-style baseline)
- `AWSManagedRulesKnownBadInputsRuleSet` (incl. Log4Shell)

Satisfies checkov `CKV_AWS_68` / `CKV2_AWS_47` (WAF attached to the distribution). The export-control
geo/anonymizer rules are **not** duplicated here — they live on the regional ALB ACL.

## Usage

```hcl
module "cloudfront_waf" {
  source     = "../../../modules/cloudfront-web-acl"
  tags       = var.tags
  count_only = true # bake in COUNT, then flip to false to enforce

  # CLOUDFRONT-scoped ACLs must be created in us-east-1:
  providers = {
    aws = aws.us-east-1
  }
}

resource "aws_cloudfront_distribution" "distribution" {
  # ...
  web_acl_id = module.cloudfront_waf.web_acl_id # ARN, per the WAFv2 CloudFront contract
}
```

## Rollout (behaviour-sensitive)

The managed rule groups can block real traffic. Set `count_only = true` first, watch the CloudWatch
metrics / sampled requests, tune false positives via `common_ruleset_count_rules` /
`known_bad_inputs_count_rules`, then set `count_only = false` to enforce. AWS-gated — no apply here.
