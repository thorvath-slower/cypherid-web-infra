variable "tags" {
  type = object({
    project = string
    env     = string
    service = string
    owner   = string
  })
  description = "Standard resource tags (project/env/service/owner)."
}

# CZID-284 — per-env enable toggle for the Layer-2 edge gate. Defaults to false so associating the
# Lambda@Edge (and standing up the edge CloudFront distribution) is an explicit, per-env, counsel/ops-gated
# decision — never silently on. When false the module creates nothing. Flipping this on is the go-live
# action (bucket-b apply), sequenced canary-first (see var.dry_run) dev → staging → prod.
variable "enabled" {
  type        = bool
  default     = false
  description = "Master switch: when false the module creates NOTHING (no distribution, no Lambda@Edge, no association). Enabling is the counsel/ops-gated go-live action."
}

variable "alb_domain_name" {
  type        = string
  description = "Domain name of the existing ALB — stays the CloudFront origin (the regional WAF on it remains Layer-1 defense-in-depth)."
}

variable "acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN for the CloudFront viewer cert. MUST be in us-east-1."
}

# --- Provider-agnostic Layer-2 config (CZID-326 selects the actual provider) ---
variable "provider_name" {
  type        = string
  description = "IP-intel provider the Lambda adapter loads: geocomply | spur | ipqs. The choice is gated on the CZID-326 RFP/PoC + counsel; baked into the artifact or read from SSM."
  default     = "spur"
  validation {
    condition     = contains(["geocomply", "spur", "ipqs"], var.provider_name)
    error_message = "provider_name must be one of: geocomply, spur, ipqs."
  }
}

# The Lambda reads the provider API key from Secrets Manager at cold start (Lambda@Edge has no env vars,
# draft §5). Two mutually-exclusive ways to supply it:
#   1. create_secret = true  → this module creates the us-east-1 secret CONTAINER (empty placeholder
#      version). Counsel/ops set the real value out-of-band; the value NEVER lives in code or tfvars.
#   2. create_secret = false → pass an already-provisioned secret via provider_secret_arn.
variable "create_secret" {
  type        = bool
  default     = true
  description = "When true, create the us-east-1 Secrets Manager secret CONTAINER (placeholder value; the real key is set out-of-band by counsel/ops). When false, use var.provider_secret_arn."
}

variable "provider_secret_arn" {
  type        = string
  default     = null
  description = "Secrets Manager ARN of the provider API key when create_secret = false. Ignored when create_secret = true (the module creates + wires its own). Must live/replicate in us-east-1 for Lambda@Edge."
}

variable "secret_name" {
  type        = string
  default     = null
  description = "Name for the created Secrets Manager secret when create_secret = true. Defaults to <project>-<env>-edge-ip-intel-provider-key. The VALUE is a placeholder — counsel/ops provision the real key."
}

variable "lambda_zip" {
  type        = string
  description = "Path to the built Lambda@Edge artifact (must be < 1 MB for a viewer-request trigger). Built from the lambda/ source in this module."
}

# CloudFront cache / origin-request policies that forward CloudFront-Viewer-Country & -Address to the
# function and origin. Use AWS-managed policy IDs or a custom policy created in the consuming env.
variable "cache_policy_id" {
  type        = string
  description = "CloudFront cache policy ID (must forward the viewer country/address headers)."
}

variable "origin_request_policy_id" {
  type        = string
  description = "CloudFront origin-request policy ID (forwards viewer headers to the origin)."
}
