output "bucket_domain_name" {
  value       = aws_s3_bucket.logs.bucket_domain_name
  description = "Set as a distribution's logging_config.bucket (e.g. <bucket>.s3.amazonaws.com)."
}

output "bucket_id" {
  value = aws_s3_bucket.logs.id
}
