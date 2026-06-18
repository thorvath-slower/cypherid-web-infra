output "policy_name" {
  value = local.policy_name
}

output "policy_document" {
  value = data.aws_iam_policy_document.orgwide-secrets-policy.json
}
