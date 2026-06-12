output "bucket_arn" {
  value     = module.aws-elb-access-logs-bucket.bucket_arn
  sensitive = false
}

output "bucket_name" {
  value     = module.aws-elb-access-logs-bucket.bucket_name
  sensitive = false
}


