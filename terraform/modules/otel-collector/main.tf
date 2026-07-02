# AWS Distro for OpenTelemetry (ADOT) collector — a gateway ECS service that receives
# OTLP from the app/worker/pipeline tasks and exports to AWS-native backends
# (CloudWatch EMF metrics, X-Ray traces, CloudWatch Logs). App tasks stay vendor-neutral
# (they only speak OTLP), so the backend can be swapped later by editing the exporters
# in the collector config alone. See #426 / OPENTEL-DESIGN.

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  name              = "${var.project}-${var.env}-otel-collector"
  metrics_namespace = var.metrics_namespace != "" ? var.metrics_namespace : "seqtoid/${var.env}"
  log_group_name    = "/${var.project}-${var.env}/otel-collector"

  # The ADOT collector reads this via the AOT_CONFIG_CONTENT env var (sourced from SSM).
  collector_config = yamlencode({
    receivers = {
      otlp = {
        protocols = {
          grpc = { endpoint = "0.0.0.0:${var.otlp_grpc_port}" }
          http = { endpoint = "0.0.0.0:${var.otlp_http_port}" }
        }
      }
    }
    processors = {
      batch = {}
    }
    exporters = {
      awsemf = {
        region    = var.region
        namespace = local.metrics_namespace
      }
      awsxray = {
        region = var.region
      }
      awscloudwatchlogs = {
        region          = var.region
        log_group_name  = local.log_group_name
        log_stream_name = "otlp-logs"
      }
    }
    service = {
      pipelines = {
        traces = {
          receivers  = ["otlp"]
          processors = ["batch"]
          exporters  = ["awsxray"]
        }
        metrics = {
          receivers  = ["otlp"]
          processors = ["batch"]
          exporters  = ["awsemf"]
        }
        logs = {
          receivers  = ["otlp"]
          processors = ["batch"]
          exporters  = ["awscloudwatchlogs"]
        }
      }
    }
  })
}

# --- one CMK encrypting both the collector log group (CKV_AWS_158) and the SSM config
#     param (CKV2_AWS_34/CKV_AWS_337). The log group may carry app OTLP logs, so on this
#     HIPAA-adjacent platform telemetry at rest is customer-managed-key encrypted. --------
data "aws_iam_policy_document" "otel_kms" {
  # A KMS key policy's resource is implicitly the key it is attached to — there is no ARN
  # to scope to, and the root `kms:*` statement is the standard AWS lockout-prevention
  # grant that delegates key administration to account IAM. These wildcard checks are
  # false positives for a *key* policy (they target identity/resource policies).
  #checkov:skip=CKV_AWS_111:key policy resource is implicitly the key itself; cannot scope
  #checkov:skip=CKV_AWS_356:key policy resource is implicitly the key itself; cannot scope
  #checkov:skip=CKV_AWS_109:root kms:* is the required lockout-prevention grant for a CMK
  statement {
    sid       = "RootAdmin"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
  statement {
    sid       = "CloudWatchLogs"
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${local.log_group_name}"]
    }
  }
}

resource "aws_kms_key" "otel" {
  description             = "${local.name} encryption (log group + collector config)"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.otel_kms.json
  tags                    = var.tags
}

# --- log group for the collector's own container logs (+ exported OTLP logs) -----------
resource "aws_cloudwatch_log_group" "collector" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.otel.arn
  tags              = var.tags
}

# --- the collector config, stored in SSM and injected as AOT_CONFIG_CONTENT -----------
resource "aws_ssm_parameter" "config" {
  name        = "/${var.project}-${var.env}-otel/collector-config"
  description = "ADOT collector config for ${var.env} (rendered by terraform)."
  type        = "SecureString"
  key_id      = aws_kms_key.otel.arn
  value       = local.collector_config
  tags        = var.tags
}

# --- IAM: task execution role (pull image, write logs, read the SSM config) -----------
data "aws_iam_policy_document" "execution_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${local.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.execution_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_extra" {
  statement {
    sid       = "ReadCollectorConfig"
    actions   = ["ssm:GetParameters", "ssm:GetParameter"]
    resources = [aws_ssm_parameter.config.arn]
  }
  statement {
    sid       = "DecryptCollectorConfig"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.otel.arn]
  }
}

resource "aws_iam_role_policy" "execution_extra" {
  name   = "${local.name}-execution-extra"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_extra.json
}

# --- IAM: task role (the collector's runtime permissions to export telemetry) ---------
data "aws_iam_policy_document" "task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task" {
  name               = "${local.name}-task"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
  tags               = var.tags
}

# The AWS-managed policy for ADOT covers CloudWatch metrics/logs + X-Ray + SSM.
resource "aws_iam_role_policy_attachment" "task_adot" {
  role       = aws_iam_role.task.name
  policy_arn = "arn:aws:iam::aws:policy/AWSDistroOpenTelemetryPolicy"
}

# --- security group: allow OTLP in from the app tasks (VPC), all out -------------------
resource "aws_security_group" "collector" {
  name        = local.name
  description = "OTLP ingress to the ${var.env} ADOT collector"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "otlp_grpc" {
  for_each          = toset(var.app_ingress_cidrs)
  security_group_id = aws_security_group.collector.id
  description       = "OTLP gRPC"
  cidr_ipv4         = each.value
  from_port         = var.otlp_grpc_port
  to_port           = var.otlp_grpc_port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "otlp_http" {
  for_each          = toset(var.app_ingress_cidrs)
  security_group_id = aws_security_group.collector.id
  description       = "OTLP HTTP"
  cidr_ipv4         = each.value
  from_port         = var.otlp_http_port
  to_port           = var.otlp_http_port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.collector.id
  description       = "collector egress (CloudWatch/X-Ray endpoints)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# --- service discovery so app tasks reach the collector at a stable DNS name ----------
resource "aws_service_discovery_private_dns_namespace" "otel" {
  name        = "${var.env}.otel.internal"
  description = "Private DNS namespace for the ${var.env} OTel collector"
  vpc         = var.vpc_id
  tags        = var.tags
}

resource "aws_service_discovery_service" "collector" {
  name = "collector"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.otel.id
    dns_records {
      type = "A"
      ttl  = 10
    }
    routing_policy = "MULTIVALUE"
  }
  health_check_custom_config {
    failure_threshold = 1
  }
  tags = var.tags
}

# --- the ADOT collector task + service ------------------------------------------------
resource "aws_ecs_task_definition" "collector" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  tags                     = var.tags

  container_definitions = jsonencode([
    {
      name      = "aws-otel-collector"
      image     = var.collector_image
      essential = true
      secrets = [
        { name = "AOT_CONFIG_CONTENT", valueFrom = aws_ssm_parameter.config.arn },
      ]
      portMappings = [
        { containerPort = var.otlp_grpc_port, protocol = "tcp" },
        { containerPort = var.otlp_http_port, protocol = "tcp" },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.collector.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "otel"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "collector" {
  name            = local.name
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.collector.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [aws_security_group.collector.id]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.collector.arn
  }

  tags = var.tags
}
