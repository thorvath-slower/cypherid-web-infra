module "s3_buckets" {
  for_each          = var.s3_buckets
  source            = "github.com/thorvath-slower/cztack//aws-s3-private-bucket?ref=0fe349fc39bcfeb0e069b4ca45a566751931089a" # cztack v0.104.2
  project           = var.tags.project
  env               = var.tags.env
  service           = var.tags.service
  owner             = var.tags.owner
  bucket_name       = each.value["name"]
  bucket_policy     = each.value["policy"]
  enable_versioning = true
}
