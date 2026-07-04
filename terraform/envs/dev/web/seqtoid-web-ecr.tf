# =============================================================================
# CZID-76 dual-push: the go-forward `seqtoid-web` ECR repository, alongside the
# legacy `idseq-web` repo (aws_ecr_repository.web-repository in main.tf).
# bin/push-docker pushes the SAME image to both during the rename transition, so
# this repo must exist for the build to succeed. Mirrors the idseq-web repo +
# lifecycle policy exactly. PURELY ADDITIVE — a NEW repo; does not touch idseq-web
# or its pushed images (plan: create-only, 0 change / 0 destroy).
# =============================================================================

resource "aws_ecr_repository" "seqtoid-web-repository" {
  #checkov:skip=CKV_AWS_51:image tag immutability is intentionally gated behind var.ecr_immutable_tags (default MUTABLE) — mirrors idseq-web (see #59/PR#110); re-enable once the deploy uses immutable sha/SemVer tags.
  name = "seqtoid-web"
  # Matches idseq-web: MUTABLE by default (the latest-tag dual-push deploy relies on it).
  image_tag_mutability = var.ecr_immutable_tags ? "IMMUTABLE" : "MUTABLE"
  force_delete         = contains(["dev", "sandbox"], var.env)

  image_scanning_configuration {
    scan_on_push = true
  }

  # CZID-59: customer-managed KMS encryption gated on var.manage_ecr_kms_cmk (absent
  # when false, matching idseq-web on the current dev env — AWS-owned key, no change).
  dynamic "encryption_configuration" {
    for_each = var.manage_ecr_kms_cmk ? [1] : []
    content {
      encryption_type = "KMS"
      kms_key         = local.ecr_kms_key_arn
    }
  }
}

resource "aws_ecr_lifecycle_policy" "seqtoid-web" {
  repository = aws_ecr_repository.seqtoid-web-repository.name

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
