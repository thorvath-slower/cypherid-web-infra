output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution fronting the ALB."
  value       = aws_cloudfront_distribution.web.id
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name — point the app DNS (CNAME) here once the edge gate is validated."
  value       = aws_cloudfront_distribution.web.domain_name
}

output "edge_lambda_qualified_arn" {
  description = "Version-qualified ARN of the Lambda@Edge function (what CloudFront associates)."
  value       = aws_lambda_function.edge_ip_intel.qualified_arn
}

output "edge_lambda_role_arn" {
  description = "IAM role ARN the edge Lambda assumes (reads the provider secret + writes logs)."
  value       = aws_iam_role.edge_lambda.arn
}
