output "otlp_grpc_endpoint" {
  description = "Set the app/worker tasks' OTEL_EXPORTER_OTLP_ENDPOINT to this."
  value       = module.otel.otlp_grpc_endpoint
}

output "otlp_http_endpoint" {
  value = module.otel.otlp_http_endpoint
}

output "collector_task_role_arn" {
  value = module.otel.collector_task_role_arn
}

output "collector_security_group_id" {
  value = module.otel.security_group_id
}
