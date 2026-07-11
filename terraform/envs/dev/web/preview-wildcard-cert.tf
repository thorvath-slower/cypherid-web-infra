# =============================================================================
# Wildcard ACM cert for per-PR preview ingress (#617). One cert -- *.dev.seqtoid.org --
# covers EVERY per-PR ALB host (pr-N.dev.seqtoid.org), so a new sandbox needs no per-host
# cert. DNS-validated against the SAME-account dev.seqtoid.org hosted zone (local.zone_id),
# so there is no cross-account step. us-west-2 (the default provider) because it terminates
# on the dev ALB -- NOT us-east-1 like the CloudFront assets cert.
#
# Mirrors module "assets-cert" (assets.tf). Additive; apply with -target. The output ARN
# goes into deploy/argocd/values/seqtoid-web/preview-base.yaml (ingress.certificateArn).
# =============================================================================
module "preview_wildcard_cert" {
  source = "../../../modules/aws-acm-certificate-v0.104.2" # cztack v0.104.2

  cert_domain_name               = "*.${local.env_fqdn}"
  aws_route53_zone_id            = local.zone_id
  cert_subject_alternative_names = {}
  tags                           = var.tags # TODO: var.tags is deprecated
  # Default aws provider (us-west-2, the ALB region).
}

output "preview_wildcard_cert_arn" {
  description = "ARN of the *.dev.seqtoid.org wildcard cert for per-PR preview ingress; set as ingress.certificateArn in preview-base.yaml."
  value       = module.preview_wildcard_cert.arn
}
