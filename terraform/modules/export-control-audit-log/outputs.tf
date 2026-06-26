output "bucket_id" {
  description = "The immutable audit-log bucket name/id — set as the WAF logging destination (after the migration)."
  value       = aws_s3_bucket.audit.id
}

output "bucket_arn" {
  description = "ARN of the immutable audit-log bucket."
  value       = aws_s3_bucket.audit.arn
}

output "firehose_arn" {
  description = "ARN of the edge-log Firehose delivery stream (empty if not created) — the per-region CloudWatch subscription filter targets this."
  value       = try(aws_kinesis_firehose_delivery_stream.edge_logs[0].arn, "")
}
