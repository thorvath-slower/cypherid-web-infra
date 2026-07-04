output "web_acl_id" {
  # CloudFront's web_acl_id argument takes the ACL ARN for WAFv2 (not the short id). See
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution#web_acl_id
  value       = aws_wafv2_web_acl.cloudfront.arn
  description = "ARN of the CLOUDFRONT-scoped Web ACL. Assign to a distribution's web_acl_id argument."
}

output "web_acl_arn" {
  value       = aws_wafv2_web_acl.cloudfront.arn
  description = "ARN of the CLOUDFRONT-scoped Web ACL."
}

output "scope" {
  value       = "CLOUDFRONT"
  description = "The ACL scope."
}
