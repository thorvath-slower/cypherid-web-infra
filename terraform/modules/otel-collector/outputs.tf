output "otlp_grpc_endpoint" {
  description = "gRPC OTLP endpoint the app/worker tasks send to (set OTEL_EXPORTER_OTLP_ENDPOINT)."
  value       = "collector.${var.env}.otel.internal:${var.otlp_grpc_port}"
}

output "otlp_http_endpoint" {
  description = "HTTP OTLP endpoint."
  value       = "http://collector.${var.env}.otel.internal:${var.otlp_http_port}"
}

output "collector_task_role_arn" {
  description = "IAM role the collector task assumes (CloudWatch/X-Ray export)."
  value       = aws_iam_role.task.arn
}

output "security_group_id" {
  description = "Collector security group (app task SGs must be allowed to reach it, or use the VPC CIDR ingress)."
  value       = aws_security_group.collector.id
}

output "config_ssm_parameter" {
  description = "SSM parameter holding the rendered collector config."
  value       = aws_ssm_parameter.config.name
}
