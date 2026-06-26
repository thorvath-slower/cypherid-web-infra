# edge-ip-intel — Layer 2 edge IP-intelligence gate (CZID-327)

CloudFront + a **viewer-request Lambda@Edge** in front of the existing ALB, screening every request for
VPN / proxy / Tor / hosting / **residential-proxy** risk before the origin. Part of the zero-tolerance
export-control program (epic **CZID-321**). The regional WAF on the ALB stays as Layer-1 defense-in-depth.

**Fail-closed:** any provider timeout/error → 403. **Geo short-circuit:** blocked country → 403 with no
provider call. See `EXPORT-CONTROL-GEO-VPN-ENFORCEMENT-2026-06-25.md` §4 and
`CLOUDFRONT-LAMBDA-EDGE-IP-INTEL-DRAFT-2026-06-25.md`.

## Provider-agnostic
The decision logic (`lambda/index.mjs`) consumes only the common contract in `lambda/adapter/index.mjs`.
Selecting GeoComply / Spur / IPQS (**CZID-326**, gated on RFP/PoC + counsel) = set `PROVIDER` + the secret;
nothing else changes. `lambda/adapter/providers/spur.mjs` is a working skeleton; `geocomply.mjs` / `ipqs.mjs`
follow the same shape.

## Usage
```hcl
module "edge_ip_intel" {
  source = "../../modules/edge-ip-intel"
  providers = {
    aws          = aws
    aws.useast1  = aws.useast1   # Lambda@Edge + the CloudFront cert MUST be us-east-1
  }
  tags                     = local.tags
  alb_domain_name          = module.alb.dns_name
  acm_certificate_arn      = var.us_east_1_cert_arn
  provider_name            = "spur"        # CZID-326 decision
  provider_secret_arn      = var.ipintel_secret_arn
  lambda_zip               = "${path.module}/build/edge-ip-intel.zip"  # < 1 MB
  cache_policy_id          = var.cache_policy_id
  origin_request_policy_id = var.origin_request_policy_id
}
```

## Build the artifact
`lambda/` → a `< 1 MB` zip (viewer-request limit). Bundle with the AWS SDK external/minimal; bake the
provider choice + secret ARN at build time (no env vars at the edge). Wire into CI before apply.

## AWS-gated (bucket-b)
Nothing here is applied. The `tofu apply` (CloudFront distribution, the published Lambda@Edge version,
the provider secret) is **bucket-b** and runs only on Tom's go-ahead, canary-first (`DRY_RUN`/log-only →
enforce), dev → staging → prod, gated on the CZID-333 evasion harness + counsel sign-off (CZID-335).
