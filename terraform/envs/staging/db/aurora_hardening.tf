# CZID-351 (DATA-2 follow-up) — RDS data-safety hardening that sits alongside the Aurora 8.0 cluster
# (aurora.tf): a customer-managed KMS key (greenfield-gated), the RDS enhanced-monitoring role, and an
# AWS Backup plan. Canonical/mirrored across envs like aurora.tf; var.manage_db_kms_cmk is the only
# greenfield-vs-live difference (the KMS key is immutable on an existing cluster).

# --- Customer-managed KMS key for RDS storage + Performance Insights (CKV_AWS_327/354) ----------
# Created ONLY where var.manage_db_kms_cmk = true (greenfield, e.g. prod). On live envs it is absent
# and local.db_kms_key_arn is null → the cluster keeps the AWS-managed key (no replacement).
resource "aws_kms_key" "rds" {
  count                   = var.manage_db_kms_cmk ? 1 : 0
  description             = "seqtoid RDS data tier (${var.env})"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = {
    terraform = true
  }
}

resource "aws_kms_alias" "rds" {
  count         = var.manage_db_kms_cmk ? 1 : 0
  name          = "alias/seqtoid-rds-${var.env}"
  target_key_id = aws_kms_key.rds[0].key_id
}

# --- Enhanced monitoring role (CKV_AWS_118) -----------------------------------------------------
data "aws_iam_policy_document" "rds_monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name               = "${var.project}-${var.env}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume.json

  tags = {
    terraform = true
  }
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# --- AWS Backup plan covering the cluster (CKV2_AWS_8) -------------------------------------------
resource "aws_backup_vault" "db" {
  name        = "${var.project}-${var.env}-db"
  kms_key_arn = local.db_kms_key_arn # null → AWS Backup default key on live envs

  tags = {
    terraform = true
  }
}

resource "aws_backup_plan" "db" {
  name = "${var.project}-${var.env}-db"

  rule {
    rule_name         = "daily-35d"
    target_vault_name = aws_backup_vault.db.name
    schedule          = "cron(0 5 * * ? *)" # 05:00 UTC daily

    lifecycle {
      delete_after = 35
    }
  }

  tags = {
    terraform = true
  }
}

data "aws_iam_policy_document" "backup_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name               = "${var.project}-${var.env}-db-backup"
  assume_role_policy = data.aws_iam_policy_document.backup_assume.json

  tags = {
    terraform = true
  }
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_selection" "db" {
  name         = "${var.project}-${var.env}-db"
  iam_role_arn = aws_iam_role.backup.arn
  plan_id      = aws_backup_plan.db.id
  resources    = [aws_rds_cluster.db.arn]
}
