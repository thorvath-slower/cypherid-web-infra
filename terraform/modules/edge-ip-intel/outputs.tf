# All outputs are null when var.enabled = false (the module creates nothing).

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution fronting the ALB (null when disabled)."
  value       = var.enabled ? aws_cloudfront_distribution.web[0].id : null
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name — point the app DNS (CNAME) here once the edge gate is validated (null when disabled)."
  value       = var.enabled ? aws_cloudfront_distribution.web[0].domain_name : null
}

output "edge_lambda_qualified_arn" {
  description = "Version-qualified ARN of the Lambda@Edge function (what CloudFront associates; null when disabled)."
  value       = var.enabled ? aws_lambda_function.edge_ip_intel[0].qualified_arn : null
}

output "edge_lambda_role_arn" {
  description = "IAM role ARN the edge Lambda assumes (reads the provider secret + writes logs; null when disabled)."
  value       = var.enabled ? aws_iam_role.edge_lambda[0].arn : null
}

output "provider_secret_arn" {
  description = "Secrets Manager ARN of the provider API key the Lambda reads (created here when create_secret=true, else the caller-supplied ARN). Bake this into the artifact via build.sh PROVIDER_SECRET_ARN. Null when disabled."
  value       = local.provider_secret_arn
}
