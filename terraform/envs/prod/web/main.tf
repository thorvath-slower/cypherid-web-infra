locals {
  # #429: normalize prod to the dev/staging seqtoid.org model. The zone + fqdn come
  # from the route53 remote state (env_seqtoid_org_*), which prod/route53 already
  # exports — the same source dev and staging consume. Drops the hardcoded idseq.net
  # domain and the idseq-prod idseq_net_zone_id lookup.
  zone_id      = data.terraform_remote_state.route53.outputs.env_seqtoid_org_zone_id
  env_fqdn     = data.terraform_remote_state.route53.outputs.env_seqtoid_org_fqdn
  www_env_fqdn = "www.${local.env_fqdn}"
}

data "aws_iam_policy_document" "idseq-web-assume-role" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com", "ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "idseq-web" {
  name               = "idseq-web-${var.env}"
  description        = "task role for idseq-web task in ${var.env} environment"
  assume_role_policy = data.aws_iam_policy_document.idseq-web-assume-role.json
}

# Attaching these permissions for the SSRF protections provided by ssrfs-up.
# The policy "ssrfs-up-invoke" is added to the baseline so all accounts have
# access to it.
# https://github.com/chanzuckerberg/SSRFs-Up
data "aws_caller_identity" "current" {}
resource "aws_iam_role_policy_attachment" "ssrfs-invoke" {
  role       = aws_iam_role.idseq-web.name
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/ssrfs-up-invoke"
}

data "aws_iam_policy_document" "idseq-web" {
  statement {
    actions = [
      "autoscaling:*",
      "batch:*",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:PutMetricData",
      "iam:List*",
      "iam:Get*",
      "iam:PassRole",
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:Describe*",
      "logs:FilterLogEvents",
      "logs:Get*",
      "logs:PutLogEvents",
      "logs:TestMetricFilter",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceAttribute",
      "ec2:DescribeInstances",
      "ec2:DescribeKeyPairs",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribePlacementGroups",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotInstanceRequests",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcClassicLink",
      "ec2:TerminateInstances",
      "ecs:Describe*",
      "ecs:List*",
      "ecs:RegisterTaskDefinition",
      "ecs:RunTask",
      "elasticloadbalancing:Describe*",
      "es:*",
      "glue:GetJobRun",
      "glue:GetJobRuns",
      "glue:StartJobRun",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:GetAccelerateConfiguration",
    ]

    resources = [
      "arn:aws:s3:::${var.s3_bucket_samples}",
      "arn:aws:s3:::${var.s3_bucket_samples_v1}",
      "arn:aws:s3:::${var.s3_bucket_public_references}",
      "arn:aws:s3:::${var.s3_bucket_idseq_bench}",
      "arn:aws:s3:::czb*",
      "arn:aws:s3:::${var.s3_bucket_aegea_ecs_execute}",
      "arn:aws:s3:::${var.s3_bucket_workflows}",
      # IDSEQ-2933 - Giving access to both buckets so migration will not cause disruptions during the switch
      #              The following line can be removed after public references are fully migrated:
      "arn:aws:s3:::idseq-database",
    ]
  }

  statement {
    actions = [
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::${var.s3_bucket_samples}/*",
      "arn:aws:s3:::${var.s3_bucket_samples_v1}/*",
      "arn:aws:s3:::${var.s3_bucket_public_references}/*",
      "arn:aws:s3:::${var.s3_bucket_idseq_bench}/*",
      "arn:aws:s3:::czb*",
      "arn:aws:s3:::${var.s3_bucket_aegea_ecs_execute}/*",
      "arn:aws:s3:::${var.s3_bucket_workflows}/*",
      # IDSEQ-2933 - Giving access to both buckets so migration will not cause disruptions during the switch
      #              The following line can be removed after public references are fully migrated:
      "arn:aws:s3:::idseq-database/*",
    ]
  }

  statement {
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
    ]

    resources = [
      "arn:aws:s3:::${var.s3_bucket_samples}/*",
      "arn:aws:s3:::${var.s3_bucket_samples_v1}/*",
      "arn:aws:s3:::${var.s3_bucket_aegea_ecs_execute}/*",
    ]
  }

  statement {
    actions = [
      "states:Describe*",
      "states:Get*",
      "states:List*",
      "states:StartExecution",
      "states:StopExecution",
    ]

    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
      "sqs:SendMessage",
      "sqs:ListQueues",
    ]

    resources = [
      "arn:aws:sqs:us-west-2:${data.aws_caller_identity.current.account_id}:idseq-${var.env}-*",
      "arn:aws:sqs:us-west-2:${data.aws_caller_identity.current.account_id}:idseq-swipe-${var.env}-*",
    ]
  }

  statement {
    actions = [
      "lambda:InvokeFunction"
    ]

    resources = [
      "arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:*"
    ]
  }

  statement {
    actions = [
      "secretsmanager:GetSecretValue"
    ]

    resources = [
      "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.env}/*",
    ]
  }
}

resource "aws_iam_role_policy" "idseq-web" {
  name   = "idseq-web-${var.env}"
  role   = aws_iam_role.idseq-web.id
  policy = data.aws_iam_policy_document.idseq-web.json
}

data "aws_iam_policy_document" "idseq-upload-assume-role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    sid     = "WebAssumeRole"

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.idseq-web.arn]
    }
  }
}

resource "aws_iam_role" "idseq-upload" {
  name               = "idseq-upload-${var.env}"
  description        = "role for users to assume to upload samples to the ${var.env} environment"
  assume_role_policy = data.aws_iam_policy_document.idseq-upload-assume-role.json
}

data "aws_iam_policy_document" "idseq-upload" {
  statement {
    sid    = "AllowSampleUploads"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]

    resources = [
      "arn:aws:s3:::${var.s3_bucket_samples}/samples/*",
    ]
  }
}

resource "aws_iam_role_policy" "idseq-upload" {
  name   = "idseq-upload-${var.env}"
  role   = aws_iam_role.idseq-upload.id
  policy = data.aws_iam_policy_document.idseq-upload.json
}

module "parameters-policy" {
  source = "../../../modules/aws-params-reader-policy-v0.104.2" # cztack v0.104.2

  project   = var.project
  env       = var.env
  service   = var.component
  region    = var.region
  role_name = aws_iam_role.idseq-web.name
}

module "web-service-params" {
  source  = "../../../modules/aws-ssm-params-writer-v0.104.2" # cztack v0.104.2
  project = var.project
  env     = var.env
  service = var.component
  owner   = var.owner

  parameters = {
    RDS_ADDRESS                   = data.terraform_remote_state.db.outputs.db_instance_address
    DB_PORT                       = data.terraform_remote_state.db.outputs.db_instance_port
    DB_USERNAME                   = data.terraform_remote_state.db.outputs.db_instance_username
    REDISCLOUD_URL                = "rediss://${data.terraform_remote_state.redis.outputs.elasticache_secure_dns_name}:6379"
    SAMPLES_BUCKET_NAME           = data.terraform_remote_state.db.outputs.samples_bucket
    SAMPLES_BUCKET_NAME_V1        = data.terraform_remote_state.db.outputs.samples_bucket_v1
    ALIGNMENT_CONFIG_DEFAULT_NAME = var.alignment_index_date
    ES_ADDRESS                    = "https://${data.terraform_remote_state.heatmap-optimization.outputs.elastic_search_endpoint}"
    CLOUDFRONT_ENDPOINT           = local.full_domain
    CZID_CLOUDFRONT_ENDPOINT      = local.full_domain
    S3_DATABASE_BUCKET            = var.s3_bucket_public_references
    CLI_UPLOAD_ROLE_ARN           = aws_iam_role.idseq-upload.arn
  }
}

module "prod" {
  source = "../../../modules/aws-acm-certificate-v0.104.2" # cztack v0.104.2

  cert_domain_name    = local.env_fqdn
  aws_route53_zone_id = local.zone_id

  cert_subject_alternative_names = {
    (local.www_env_fqdn) = local.zone_id
  }

  tags = var.tags
}

module "web-service" {
  source = "../../../modules/ecs-service-with-alb-v0.421.0"

  service             = "web"
  container_port      = 3000
  container_name      = "rails"
  env                 = var.env
  vpc_id              = data.terraform_remote_state.cloud-env.outputs.vpc_id
  cluster_id          = data.terraform_remote_state.ecs.outputs.cluster_id
  task_role_arn       = aws_iam_role.idseq-web.arn
  desired_count       = 6
  lb_subnets          = data.terraform_remote_state.cloud-env.outputs.public_subnets
  route53_zone_id     = local.zone_id
  subdomain           = var.env
  health_check_path   = "/health_check"
  acm_certificate_arn = module.prod.arn
  lb_egress_cidrs     = [data.terraform_remote_state.cloud-env.outputs.vpc_cidr_block]
  project             = var.project
  owner               = var.owner
  access_logs_bucket  = data.terraform_remote_state.elb-access-logs.outputs.bucket_name
  # The AWS and module default is 60s. We decided to increase it after observing
  # multiple endpoints exceeding that in production under normal loads, including
  # bulk_upload_with_metadata and report_csv.
  lb_idle_timeout_seconds = 300
  ssl_policy              = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

resource "aws_route53_record" "www" {
  zone_id = local.zone_id
  name    = local.www_env_fqdn
  type    = "A"

  alias {
    name                   = module.web-service.alb_dns_name
    zone_id                = module.web-service.alb_route53_zone_id
    evaluate_target_health = false
  }
}


resource "aws_ecr_repository" "web-repository" {
  name = "idseq-web"
  # CZID-59: IMMUTABLE tags (CKV_AWS_51). This is an in-place update on an existing
  # repo (PutImageTagMutability), NOT a replacement.
  image_tag_mutability = var.ecr_immutable_tags ? "IMMUTABLE" : "MUTABLE"
  force_delete         = contains(["dev", "sandbox"], var.env)

  image_scanning_configuration {
    scan_on_push = true
  }

  # CZID-59: customer-managed KMS encryption of image layers (CKV_AWS_136), gated on
  # var.manage_ecr_kms_cmk. encryption_configuration is IMMUTABLE — enabling it on an
  # existing repo forces DESTROY+RECREATE, so it is emitted ONLY on greenfield envs
  # (see ecr_hardening.tf). When the var is false the block is absent and the repo
  # keeps the AWS-owned key with no change.
  dynamic "encryption_configuration" {
    for_each = var.manage_ecr_kms_cmk ? [1] : []
    content {
      encryption_type = "KMS"
      kms_key         = local.ecr_kms_key_arn
    }
  }
}

resource "aws_ecr_lifecycle_policy" "idseq-web" {
  repository = aws_ecr_repository.web-repository.name

  policy = jsonencode({
    rules = [
      {
        action = {
          type = "expire"
        },
        selection : {
          countType     = "imageCountMoreThan",
          countNumber   = 1,
          tagStatus     = "tagged",
          tagPrefixList = ["latest"],
        },
        description    = "Always keep the one image tagged as latest (there should only be one). \"An image that matches the tagging requirements of a rule cannot be expired by a rule with a lower priority.\"",
        "rulePriority" = 1
      },
      {
        rulePriority = 2,
        description  = "Remove all images after 365 days (except for the image tagged \"latest\")",
        selection = {
          tagStatus   = "any",
          countType   = "sinceImagePushed",
          countUnit   = "days",
          countNumber = 365
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}

