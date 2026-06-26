variable "tags" {
  type = object({
    project = string
    env     = string
    service = string
    owner   = string
  })
  description = "Standard resource tags (project/env/service/owner)."
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

variable "provider_secret_arn" {
  type        = string
  description = "Secrets Manager ARN of the provider API key. Lambda@Edge has no env vars, so the function reads it at cold start and caches it (draft §5). Replicate the secret to us-east-1."
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
