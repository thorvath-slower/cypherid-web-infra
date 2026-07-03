# CZID-284 — Layer-2 edge IP-intel gate wire-in (dev). GATED: disabled by default (var.edge_ip_intel_enabled
# = false), so this stack plans/applies with NO edge Lambda@Edge, NO extra CloudFront distribution, and NO
# viewer-request association until an explicit, counsel/ops-approved enable. This is the integration point
# for the module defined in terraform/modules/edge-ip-intel — it associates the version-qualified
# Lambda@Edge as a `viewer-request` function in front of the web ALB. Enabling is bucket-b (AWS-gated),
# canary-first (Lambda DRY_RUN log-only → enforce), dev → staging → prod, gated on the CZID-333 evasion
# harness + counsel sign-off (CZID-335).
#
# Fail-closed data path note (GUARDRAIL): this fronts the END-USER request path (upload → process →
# result). It stays internet-facing; the gate DENIES on ambiguity/anonymizer/geo but never dead-ends a
# clean user. DNS is NOT repointed here — cut over to module.edge_ip_intel.cloudfront_domain_name only
# after validation (a separate, deliberate step), so a mistaken enable cannot black-hole the app.

variable "edge_ip_intel_enabled" {
  type        = bool
  default     = false
  description = "CZID-284: enable the Layer-2 edge IP-intel gate in dev. Counsel/ops-gated go-live switch; keep false until sign-off."
}

variable "edge_ip_intel_lambda_zip" {
  type        = string
  default     = "../../../modules/edge-ip-intel/lambda/edge-ip-intel.zip"
  description = "Path to the built Lambda@Edge artifact (built by modules/edge-ip-intel/lambda/build.sh; < 1 MB). Only read when edge_ip_intel_enabled = true."
}

variable "edge_ip_intel_provider_name" {
  type        = string
  default     = "spur"
  description = "CZID-326 engineering lean; FINAL provider is counsel/procurement's. Must match the value baked into the artifact by build.sh."
}

# AWS-managed policy IDs that forward CloudFront-Viewer-Address / -Country to the function + origin.
# Defaults: AllViewerAndCloudFrontHeaders-2022-06 (origin-request) and CachingDisabled (cache). Override
# per-env if a custom policy is required. Only read when enabled.
variable "edge_ip_intel_cache_policy_id" {
  type        = string
  default     = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
  description = "CloudFront cache policy ID (must forward viewer country/address)."
}

variable "edge_ip_intel_origin_request_policy_id" {
  type        = string
  default     = "33f36d7e-f396-46d9-90e0-52428a34d9dc" # Managed-AllViewerAndCloudFrontHeaders-2022-06
  description = "CloudFront origin-request policy ID (forwards viewer headers to the origin)."
}

module "edge_ip_intel" {
  source = "../../../modules/edge-ip-intel"

  providers = {
    aws         = aws
    aws.useast1 = aws.us-east-1 # Lambda@Edge + the CloudFront cert MUST be us-east-1
  }

  enabled = var.edge_ip_intel_enabled

  tags = {
    project = var.tags.project
    env     = var.tags.env
    service = var.tags.service
    owner   = var.tags.owner
  }

  alb_domain_name     = module.web-service.alb_dns_name
  acm_certificate_arn = module.staging_east.arn # us-east-1 cert (CloudFront requirement)

  provider_name = var.edge_ip_intel_provider_name
  # create_secret defaults true → the module stands up the us-east-1 secret CONTAINER (placeholder value;
  # counsel/ops set the real key out-of-band). Bake module.edge_ip_intel.provider_secret_arn into the
  # artifact via build.sh PROVIDER_SECRET_ARN before enabling.

  lambda_zip               = var.edge_ip_intel_lambda_zip
  cache_policy_id          = var.edge_ip_intel_cache_policy_id
  origin_request_policy_id = var.edge_ip_intel_origin_request_policy_id
}
