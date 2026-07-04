output "bucket_domain_name" {
  # Assign to a distribution's logging_config.bucket (S3 bucket domain, e.g. name.s3.amazonaws.com).
  value       = "${module.logs_bucket.name}.s3.amazonaws.com"
  description = "S3 bucket domain name for the distribution logging_config.bucket argument."
}

output "bucket_name" {
  value       = module.logs_bucket.name
  description = "Name of the CloudFront access-logs bucket."
}

output "bucket_arn" {
  value       = module.logs_bucket.arn
  description = "ARN of the CloudFront access-logs bucket."
}
