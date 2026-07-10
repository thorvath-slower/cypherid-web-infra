# =============================================================================
# Per-PR PREVIEW image repository — seqtoid-web-preview (#613, branching-model work).
#
# A feature branch -> PR into `integration` builds an isolated preview image that is
# NEVER promoted (main/dev pull from idseq-web / seqtoid-web). Keeping preview images
# in their OWN repo means: (a) a per-PR build role can be scoped to ecr:push on THIS
# repo only (blast radius of a malicious PR build = a junk image here, nothing else),
# and (b) an aggressive expiry keeps ephemeral PR images from accumulating cost.
#
# MUTABLE tags: a PR re-push reuses `sha-<prSha>` / `branch-<ref>` tags. force_delete
# on dev/sandbox so the repo can be torn down cleanly. PURELY ADDITIVE — a NEW repo;
# does not touch idseq-web or seqtoid-web (plan: create-only, 0 change / 0 destroy).
# =============================================================================

resource "aws_ecr_repository" "seqtoid-web-preview" {
  #checkov:skip=CKV_AWS_51:preview images are ephemeral throwaways rebuilt per PR push; immutable tags would break the sha-<prSha> re-push and serve no supply-chain purpose (these are never promoted).
  name                 = "seqtoid-web-preview"
  image_tag_mutability = "MUTABLE"
  force_delete         = contains(["dev", "sandbox"], var.env)

  image_scanning_configuration {
    scan_on_push = true
  }

  # Mirror seqtoid-web's KMS gate (AWS-owned key on dev unless var.manage_ecr_kms_cmk).
  dynamic "encryption_configuration" {
    for_each = var.manage_ecr_kms_cmk ? [1] : []
    content {
      encryption_type = "KMS"
      kms_key         = local.ecr_kms_key_arn
    }
  }
}

# Aggressive expiry — previews are throwaway. Keep the shared :buildcache tag, expire
# untagged layers fast, and cap the number of PR image tags retained.
resource "aws_ecr_lifecycle_policy" "seqtoid-web-preview" {
  repository = aws_ecr_repository.seqtoid-web-preview.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the build cache tag (buildcache) — not a PR image."
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["buildcache"]
          countType     = "imageCountMoreThan"
          countNumber   = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Expire untagged layers after 3 days."
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 3
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 3
        description  = "Retain at most the 30 most-recent PR image tags."
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = { type = "expire" }
      }
    ]
  })
}

output "seqtoid_web_preview_ecr_url" {
  description = "Repository URL for the per-PR preview images (seqtoid-web-preview)."
  value       = aws_ecr_repository.seqtoid-web-preview.repository_url
}
