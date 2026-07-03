output "bastion_instance_id" {
  description = "EC2 instance ID of the SSM bastion. Connect: aws ssm start-session --target <id>"
  value       = aws_instance.bastion.id
}

output "bastion_security_group_id" {
  description = "Security group ID of the SSM bastion."
  value       = aws_security_group.bastion.id
}

output "bastion_iam_role_name" {
  description = "IAM role name of the SSM bastion instance profile."
  value       = aws_iam_role.bastion.name
}
