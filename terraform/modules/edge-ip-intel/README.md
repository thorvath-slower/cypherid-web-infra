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

## Usage (CZID-284)
Disabled by default — `enabled = false` creates **nothing**. Turning it on is the counsel/ops-gated
go-live action; the wire-in lives in each env `web` stack (see `terraform/envs/dev/web/edge-ip-intel.tf`,
also gated behind `var.edge_ip_intel_enabled`).
```hcl
module "edge_ip_intel" {
  source = "../../../modules/edge-ip-intel"
  providers = {
    aws         = aws
    aws.useast1 = aws.us-east-1   # Lambda@Edge + the CloudFront cert MUST be us-east-1
  }
  enabled                  = var.edge_ip_intel_enabled  # GATED — false until sign-off
  tags                     = local.tags
  alb_domain_name          = module.web-service.alb_dns_name  # existing ALB stays the origin
  acm_certificate_arn      = module.staging_east.arn          # us-east-1 cert
  provider_name            = "spur"        # CZID-326 engineering lean; FINAL choice = counsel/procurement
  # create_secret defaults true → the module stands up the us-east-1 secret CONTAINER (placeholder value)
  lambda_zip               = "${path.module}/../../../modules/edge-ip-intel/lambda/edge-ip-intel.zip" # < 1 MB
  cache_policy_id          = var.edge_ip_intel_cache_policy_id
  origin_request_policy_id = var.edge_ip_intel_origin_request_policy_id
}
```

### What CZID-284 wired
- **Viewer-request association.** The edge Lambda is associated on the CloudFront `default_cache_behavior`
  as a `viewer-request` `lambda_function_association` using the **version-qualified** ARN
  (`aws_lambda_function.edge_ip_intel[0].qualified_arn`) — Lambda@Edge cannot associate `$LATEST`.
- **Per-env toggle.** `var.enabled` (module) + `var.edge_ip_intel_enabled` (env stack), both default
  `false`, so nothing associates until an explicit enable. DNS is **not** repointed automatically.
- **Credential path (no env vars at the edge).** The API key lives in Secrets Manager (us-east-1). The
  module creates the secret **container** (`create_secret = true`, placeholder value) and the execution
  role gets a least-privilege `secretsmanager:GetSecretValue` scoped to that one ARN + CloudWatch Logs.
  The secret **ARN** and the provider name are **baked into the artifact** by `build.sh` (`config.mjs`) —
  the Lambda reads the key at cold start via SigV4 in `lambda/secrets.mjs` (stdlib-only), caches it for
  the warm container, and **fails closed** if unconfigured.
- **Real provider call + caching.** `lambda/adapter/providers/spur.mjs` uses Node's built-in `https`
  (no `@aws-sdk/*` — the 1 MB viewer-request limit) with an 800 ms hard timeout and a short-TTL in-memory
  LRU verdict cache keyed by client IP (`lambda/cache.mjs`). Any error/timeout/non-2xx/malformed body
  throws → the handler returns 403. There is no allow path on the error side.

## Build the artifact
`lambda/build.sh` → a `< 1 MB` zip (viewer-request limit), **stdlib-only** (no `node_modules`). Pass the
provider secret ARN + provider name so they're baked at build time (no env vars at the edge):
```sh
PROVIDER_SECRET_ARN="$(terraform output -raw provider_secret_arn)" \
PROVIDER_NAME=spur \
  terraform/modules/edge-ip-intel/lambda/build.sh
```
An empty `PROVIDER_SECRET_ARN` leaves the inert `@@placeholder@@` → the Lambda fails **closed** until a
real ARN is baked. Wire this into CI before any apply.

## Tests
`node --test 'terraform/modules/edge-ip-intel/lambda/test/*.test.mjs'` — **20 tests, offline, no network**
(fail-closed handler matrix + provider normalize + LRU + unconfigured-secret fail-closed).

## AWS-gated (bucket-b)
Nothing here is applied. The `tofu apply` (CloudFront distribution, the published Lambda@Edge version,
the provider secret) is **bucket-b** and runs only on Tom's go-ahead, canary-first (`DRY_RUN`/log-only →
enforce), dev → staging → prod, gated on the CZID-333 evasion harness + counsel sign-off (CZID-335).
