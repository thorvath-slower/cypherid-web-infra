resource "aws_s3_bucket" "pipeline_public_assets" {
  bucket = var.s3_bucket_pipeline_public_assets

  tags = {
    env       = var.env
    terraform = "true"
  }
}

# The inline `acl`, `versioning`, `cors_rule`, and `website` sub-arguments of
# `aws_s3_bucket` were deprecated in AWS provider v4 and moved to dedicated
# `aws_s3_bucket_*` resources (#475). Apply-safe: no bucket recreation, so no
# `moved {}` blocks are required. Applying the canned `public-read` ACL via the
# standalone resource requires ownership controls that permit ACLs
# (BucketOwnerPreferred), which the account previously allowed implicitly.
resource "aws_s3_bucket_ownership_controls" "pipeline_public_assets" {
  #checkov:skip=CKV2_AWS_65:this is an intentionally public read-only static-website bucket; ACLs must stay enabled (BucketOwnerPreferred) so the public-read canned ACL applies (preexisting behavior)
  bucket = aws_s3_bucket.pipeline_public_assets.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "pipeline_public_assets" {
  #checkov:skip=CKV_AWS_20:this is an intentionally public read-only bucket for pipeline assets served as a static website (preexisting behavior)
  bucket = aws_s3_bucket.pipeline_public_assets.id
  acl    = "public-read"

  depends_on = [aws_s3_bucket_ownership_controls.pipeline_public_assets]
}

resource "aws_s3_bucket_versioning" "pipeline_public_assets" {
  bucket = aws_s3_bucket.pipeline_public_assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_cors_configuration" "pipeline_public_assets" {
  bucket = aws_s3_bucket.pipeline_public_assets.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_website_configuration" "pipeline_public_assets" {
  bucket = aws_s3_bucket.pipeline_public_assets.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}
