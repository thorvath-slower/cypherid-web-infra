# CZID-327 / CZID-284 — Layer 2: CloudFront + Lambda@Edge IP-intelligence gate (export control, epic CZID-321).
#
# This is the ONLY AWS-native place to call an IP-intel provider per-request, at the edge, before the
# origin: a Lambda@Edge on the viewer-request trigger. It sits IN FRONT of the existing regional WAF/ALB
# (both stay — defense-in-depth). Fail-closed: any provider error/timeout → 403.
#
# Provider-agnostic by design: GeoComply / Spur / IPQS (CZID-326) is selected by `var.provider_name` +
# the provider secret; nothing else here changes. The provider choice is gated on RFP/PoC + counsel.
#
# CZID-284 (this change): the module is now (a) gated behind `var.enabled` so associating the edge Lambda
# is an explicit per-env decision, and (b) able to create its own us-east-1 Secrets Manager secret
# CONTAINER (placeholder value; counsel/ops set the real key out-of-band). The viewer-request
# `lambda_function_association` uses the version-qualified ARN.
#
# AWS-GATED (bucket-b): nothing is applied. Lambda@Edge MUST be created/published in us-east-1, so this
# module is consumed with `providers = { aws.useast1 = aws.useast1 }`.

locals {
  create = var.enabled ? 1 : 0

  # Which secret ARN the Lambda role is scoped to and the artifact is baked with: the one this module
  # creates, or the caller-supplied one. Guarded so a misconfiguration surfaces at plan time.
  provider_secret_arn = var.create_secret ? (
    var.enabled ? aws_secretsmanager_secret.provider_key[0].arn : null
  ) : var.provider_secret_arn

  secret_name = coalesce(var.secret_name, "${var.tags.project}-${var.tags.env}-edge-ip-intel-provider-key")
}

# --- Provider API-key secret CONTAINER (us-east-1) -----------------------------------------------------
# CZID-284: create the secret *container* only. The real key is provisioned OUT OF BAND by counsel/ops
# (never in code, never in tfvars, never in state as a real value). We seed an inert placeholder version
# so the resource is well-formed; the Lambda fails CLOSED until a real value is set (bad/placeholder key
# → provider 401/403 → throw → 403). checkov: the placeholder is intentional, not a committed secret.
resource "aws_secretsmanager_secret" "provider_key" {
  # checkov:skip=CKV2_AWS_57: automatic rotation is a counsel/ops go-live decision — the value is a
  # placeholder set out-of-band and most IP-intel provider API keys are long-lived/manually rotated; the
  # rotation policy is chosen at enable time, not here (gated placeholder, see PROVIDER-EVAL §CZID-284).
  count       = (var.enabled && var.create_secret) ? 1 : 0
  provider    = aws.useast1
  name        = local.secret_name
  description = "Layer-2 IP-intel provider API key (CZID-326 provider). VALUE is counsel/ops-provisioned out-of-band; do NOT put a real key in code/tfvars."
  tags        = var.tags
}

# checkov:skip=CKV_AWS_149: no CMK — the value is a placeholder set out-of-band; KMS choice is an ops/counsel decision at go-live.
resource "aws_secretsmanager_secret_version" "provider_key_placeholder" {
  count         = (var.enabled && var.create_secret) ? 1 : 0
  provider      = aws.useast1
  secret_id     = aws_secretsmanager_secret.provider_key[0].id
  secret_string = jsonencode({ api_key = "PLACEHOLDER-set-out-of-band-by-counsel-ops" })

  # The real key is rotated in by counsel/ops out-of-band; never let a re-apply clobber it back to the
  # placeholder once a real value exists.
  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_iam_role" "edge_lambda" {
  count    = local.create
  provider = aws.useast1
  name     = "${var.tags.project}-${var.tags.env}-edge-ip-intel"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Action    = "sts:AssumeRole",
      Principal = { Service = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"] }
    }]
  })
  tags = var.tags
}

# Least privilege: read the provider API key from Secrets Manager (Lambda@Edge has no env vars, so the
# key is fetched at cold start, §5 of the draft), and write CloudWatch logs in the edge region.
data "aws_iam_policy_document" "edge_lambda" {
  count = local.create
  statement {
    sid       = "ReadProviderSecret"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [local.provider_secret_arn]
  }
  statement {
    sid     = "WriteEdgeLogs"
    effect  = "Allow"
    actions = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    # Lambda@Edge replicates to many regions and prefixes the log group with the edge region + the
    # us-east-1 function name, so the region/account/group cannot be fully known at plan time. Scoped to
    # the log-group namespace for this function's name across regions/accounts.
    resources = ["arn:aws:logs:*:*:log-group:/aws/lambda/*.${var.tags.project}-${var.tags.env}-edge-ip-intel:*"]
  }
}

resource "aws_iam_role_policy" "edge_lambda" {
  count    = local.create
  provider = aws.useast1
  name     = "edge-ip-intel"
  role     = aws_iam_role.edge_lambda[0].id
  policy   = data.aws_iam_policy_document.edge_lambda[0].json
}

resource "aws_lambda_function" "edge_ip_intel" {
  count            = local.create
  provider         = aws.useast1
  function_name    = "${var.tags.project}-${var.tags.env}-edge-ip-intel"
  role             = aws_iam_role.edge_lambda[0].arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = var.lambda_zip # built artifact, < 1 MB (viewer-request limit)
  source_code_hash = filebase64sha256(var.lambda_zip)
  publish          = true # Lambda@Edge requires a published version
  timeout          = 5    # viewer-request hard limit
  memory_size      = 128  # viewer-request hard limit
  # NOTE: no `environment {}` — Lambda@Edge forbids user env vars. Config (provider name + secret ARN) is
  # BAKED into the artifact (lambda/config.mjs) by build.sh; the API key is read from Secrets Manager at
  # cold start via SigV4 (lambda/secrets.mjs, stdlib-only). See lambda/adapter/providers/spur.mjs.
  tags = var.tags
}

resource "aws_cloudfront_distribution" "web" {
  # checkov:skip=CKV2_AWS_47: Log4j/AMR protection stays on the REGIONAL WAFv2 on the ALB (Layer-1,
  # defense-in-depth) — this edge distribution deliberately does not re-attach a WebACL (the Layer-2 job
  # here is the IP-intel Lambda@Edge). Attaching a CloudFront WebACL is a separate ops decision at go-live.
  # checkov:skip=CKV2_AWS_32: a response-headers policy is an app/security-header concern owned by the web
  # stack, not this export-control gate; adding one here is out of CZID-284 scope (gated to go-live).
  count           = local.create
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.tags.project}-${var.tags.env} edge IP-intel gate (CZID-327)"

  origin {
    domain_name = var.alb_domain_name # the existing ALB stays the origin
    origin_id   = "alb"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]

    # Layer 2 (CZID-284): every viewer request is screened before the cache, using the VERSION-QUALIFIED
    # function ARN (Lambda@Edge cannot associate $LATEST — it requires a specific published version).
    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = aws_lambda_function.edge_ip_intel[0].qualified_arn
      include_body = false
    }

    # Pass the real viewer IP + country through to the function/origin.
    cache_policy_id          = var.cache_policy_id
    origin_request_policy_id = var.origin_request_policy_id
  }

  # Geo + AnonymousIpList stay on the regional WAF (Layer 1, defense-in-depth). Not duplicated here.
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn # MUST be in us-east-1 for CloudFront
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = var.tags
}
