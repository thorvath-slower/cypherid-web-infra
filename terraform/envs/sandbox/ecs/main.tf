locals {
  # Off-hours window (UTC) for scheduled scale-to-zero — see ecs_scale_to_zero.tf (CZID-292 / #248).
  off_hour_utc = 3  # scale cluster to 0
  on_hour_utc  = 13 # scale cluster back to baseline
}

module "ecs-cluster" {
  source = "../../../modules/ecs-cluster-v2.4.0"

  region  = var.region
  project = var.project
  owner   = var.owner
  env     = var.env
  ami     = "ami-0010b929226fe8eba" //TODO - pull dynamically - aws ssm get-parameters --names /aws/service/ecs/optimized-ami/amazon-linux-2023/recommended --region us-east-1

  min_servers                        = 1
  max_servers                        = 2
  cluster_asg_rolling_interval_hours = 0

  # NOTE: off_hour_utc/on_hour_utc were previously passed here but the
  # ecs-cluster-v2.4.0 module does not declare them (they were silently
  # broken — `terraform init` errored with "Unsupported argument"). Off-hours
  # scale-to-zero is now implemented with real aws_autoscaling_schedule
  # resources in ecs_scale_to_zero.tf, reusing the local.*_hour_utc window.

  instance_type = "c6a.xlarge"
  vpc_id        = data.terraform_remote_state.cloud-env.outputs.vpc_id
  //ssh_key_name        = "idseq-${var.env}"
  subnets             = data.terraform_remote_state.cloud-env.outputs.private_subnets
  allowed_cidr_blocks = [data.terraform_remote_state.cloud-env.outputs.vpc_cidr_block]
  //ssh_users           = data.terraform_remote_state.global.outputs.ssh_users
  docker_storage_size = "214"
}

resource "aws_cloudwatch_log_group" "ecs" {
  name = "ecs-logs-${var.env}"
}

resource "aws_autoscaling_policy" "scale-up" {
  name                   = "ecs-scale-up-${var.env}"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
  autoscaling_group_name = module.ecs-cluster.asg_name
}

resource "aws_autoscaling_policy" "scale-down" {
  name                   = "ecs-scale-down-${var.env}"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = module.ecs-cluster.asg_name
}

//TODO - for prod, this is the definition that will be used, as the prod ASG will not scale down off hours, so the alarm should always be active
# resource "aws_cloudwatch_metric_alarm" "memory-res-high" {
#   alarm_name  = "mem-res-high-ecs-${var.env}"
#   namespace   = "AWS/ECS"
#   metric_name = "MemoryReservation"

#   dimensions = {
#     ClusterName = module.ecs-cluster.cluster_name
#   }

#   comparison_operator = "GreaterThanOrEqualToThreshold"
#   evaluation_periods  = "2"
#   period              = "300"
#   statistic           = "Average"
#   threshold           = "80"

#   alarm_actions = [
#     aws_autoscaling_policy.scale-up.arn,
#   ]
# }

resource "aws_cloudwatch_metric_alarm" "memory-res-high" {
  alarm_name          = "mem-res-high-ecs-${var.env}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  threshold           = "80"
  alarm_actions = [
    aws_autoscaling_policy.scale-up.arn
  ]

  metric_query {
    id          = "e1"
    expression  = "IF((HOUR(m1) >= ${local.off_hour_utc} AND HOUR(m1) < ${local.on_hour_utc}) OR DAY(m1)==7 OR (DAY(m1) == 6 AND HOUR(m1) >= ${local.off_hour_utc}) OR (DAY(m1) == 1 AND HOUR(m1) < ${local.on_hour_utc}), 70, m1)"
    label       = "Off Hours"
    return_data = "true"
  }

  metric_query {
    id = "m1"

    metric {
      metric_name = "MemoryReservation"
      namespace   = "AWS/ECS"
      period      = "300"
      stat        = "Average"

      dimensions = {
        ClusterName = module.ecs-cluster.cluster_name
      }
    }
  }
}

//TODO - for prod, this is the definition that will be used, as the prod ASG will not scale down off hours, so the alarm should always be active
# resource "aws_cloudwatch_metric_alarm" "memory-res-low" {
#   alarm_name  = "mem-res-low-ecs-${var.env}"
#   namespace   = "AWS/ECS"
#   metric_name = "MemoryReservation"

#   dimensions = {
#     ClusterName = module.ecs-cluster.cluster_name
#   }

#   comparison_operator = "LessThanOrEqualToThreshold"
#   evaluation_periods  = "2"
#   period              = "300"
#   statistic           = "Average"
#   threshold           = "60"

#   alarm_actions = [
#     aws_autoscaling_policy.scale-down.arn,
#   ]
# }

resource "aws_cloudwatch_metric_alarm" "memory-res-low" {
  alarm_name          = "mem-res-low-ecs-${var.env}"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  threshold           = "60"
  alarm_actions = [
    aws_autoscaling_policy.scale-down.arn
  ]

  metric_query {
    id          = "e1"
    expression  = "IF((HOUR(m1) >= ${local.off_hour_utc} AND HOUR(m1) < ${local.on_hour_utc}) OR DAY(m1)==7 OR (DAY(m1) == 6 AND HOUR(m1) >= ${local.off_hour_utc}) OR (DAY(m1) == 1 AND HOUR(m1) < ${local.on_hour_utc}), 70, m1)"
    label       = "Off Hours"
    return_data = "true"
  }

  metric_query {
    id = "m1"

    metric {
      metric_name = "MemoryReservation"
      namespace   = "AWS/ECS"
      period      = "300"
      stat        = "Average"

      dimensions = {
        ClusterName = module.ecs-cluster.cluster_name
      }
    }
  }
}

resource "aws_ecs_cluster" "idseq-fargate-tasks" {
  name = "idseq-fargate-tasks-${var.env}"
}

resource "aws_s3_bucket" "aegea-ecs-execute" {
  bucket = var.s3_bucket_aegea_ecs_execute

  tags = {
    env       = var.env
    terraform = "true"
  }
}

# Inline `acl` and `lifecycle_rule` were deprecated in AWS provider v4 and moved
# to dedicated `aws_s3_bucket_*` resources (#475). Apply-safe: no bucket recreation.
resource "aws_s3_bucket_acl" "aegea-ecs-execute" {
  bucket = aws_s3_bucket.aegea-ecs-execute.id
  acl    = "private"
}

resource "aws_s3_bucket_lifecycle_configuration" "aegea-ecs-execute" {
  bucket = aws_s3_bucket.aegea-ecs-execute.id

  rule {
    id     = "ExpireRule"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_versioning" "aegea-ecs-execute" {
  bucket = aws_s3_bucket.aegea-ecs-execute.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "aegea-ecs-execute" {
  bucket                  = aws_s3_bucket.aegea-ecs-execute.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "aegea-ecs-execute" {
  bucket = aws_s3_bucket.aegea-ecs-execute.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# --- S3 server access logging (CZID-343) ---
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "access_logs" {
  #checkov:skip=CKV_AWS_145:S3 access-log delivery is unsupported with the aws/s3 managed KMS key; AES256 is the supported at-rest option for log destinations
  #checkov:skip=CKV_AWS_18:a log-destination bucket does not log to itself (would recurse)
  #checkov:skip=CKV_AWS_144:cross-region replication is not warranted for short-lived access logs
  #checkov:skip=CKV2_AWS_62:no event-notification consumer for access logs
  bucket = "ecs-s3-access-logs-${var.env}-${data.aws_caller_identity.current.account_id}"
  tags   = { terraform = true }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    id     = "expire-access-logs"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_policy" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "S3ServerAccessLogsPolicy"
      Effect    = "Allow"
      Principal = { Service = "logging.s3.amazonaws.com" }
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.access_logs.arn}/*"
      Condition = {
        ArnLike      = { "aws:SourceArn" = [aws_s3_bucket.aegea-ecs-execute.arn] }
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })
}

resource "aws_s3_bucket_logging" "aegea-ecs-execute" {
  bucket        = aws_s3_bucket.aegea-ecs-execute.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "aegea-ecs-execute/"
}
