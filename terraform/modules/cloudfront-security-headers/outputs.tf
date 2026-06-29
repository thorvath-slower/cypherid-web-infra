output "policy_id" {
  value       = aws_cloudfront_response_headers_policy.this.id
  description = "Attach to a distribution cache behavior's response_headers_policy_id."
}
