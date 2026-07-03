locals {
  aws_account         = var.aws_accounts.idseq-dev
  aws_profile         = var.aws_profile
  force_image_rebuild = var.force_image_rebuild
  region              = var.region
  tags                = var.tags
}
