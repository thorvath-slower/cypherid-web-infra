# CZID-327 — Layer 2: CloudFront + Lambda@Edge IP-intelligence gate (export control, epic CZID-321).
#
# This is the ONLY AWS-native place to call an IP-intel provider per-request, at the edge, before the
# origin: a Lambda@Edge on the viewer-request trigger. It sits IN FRONT of the existing regional WAF/ALB
# (both stay — defense-in-depth). Fail-closed: any provider error/timeout → 403.
#
# Provider-agnostic by design: GeoComply / Spur / IPQS (CZID-326) is selected by `var.provider_name` +
# `var.provider_secret_arn`; nothing else here changes. The provider choice is gated on RFP/PoC + counsel.
#
# AWS-GATED (bucket-b): nothing is applied. Lambda@Edge MUST be created/published in us-east-1, so this
# module is consumed with `providers = { aws.useast1 = aws.useast1 }`.

resource "aws_iam_role" "edge_lambda" {
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
  statement {
    sid       = "ReadProviderSecret"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.provider_secret_arn]
  }
  statement {
    sid       = "WriteEdgeLogs"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role_policy" "edge_lambda" {
  provider = aws.useast1
  name     = "edge-ip-intel"
  role     = aws_iam_role.edge_lambda.id
  policy   = data.aws_iam_policy_document.edge_lambda.json
}

resource "aws_lambda_function" "edge_ip_intel" {
  provider         = aws.useast1
  function_name    = "${var.tags.project}-${var.tags.env}-edge-ip-intel"
  role             = aws_iam_role.edge_lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = var.lambda_zip # built artifact, < 1 MB (viewer-request limit)
  source_code_hash = filebase64sha256(var.lambda_zip)
  publish          = true # Lambda@Edge requires a published version
  timeout          = 5    # viewer-request hard limit
  memory_size      = 128  # viewer-request hard limit
  # NOTE: no `environment {}` — Lambda@Edge forbids env vars. Config (provider, blocked list, secret)
  # is read from Secrets Manager / SSM at cold start, or baked into the artifact (see the Lambda code).
  tags = var.tags
}

resource "aws_cloudfront_distribution" "web" {
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

    # Layer 2: every viewer request is screened before the cache.
    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = aws_lambda_function.edge_ip_intel.qualified_arn # version-qualified
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
