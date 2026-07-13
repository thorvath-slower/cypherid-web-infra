output "role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller. Fill into the Argo CD LBC Application's REPLACE_LBC_IAM_ROLE_ARN placeholder at bootstrap."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "IAM role name for the AWS Load Balancer Controller."
  value       = aws_iam_role.this.name
}

output "policy_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM policy."
  value       = aws_iam_policy.this.arn
}
