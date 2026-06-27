output "role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller."
  value       = module.this.iam_role_arn
}
