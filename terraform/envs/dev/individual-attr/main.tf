module "individual-attr" {
  source                      = "../../../modules/individual-attr"
  aws_account_id              = local.aws_account_id
  s3_bucket_public_references = local.s3_bucket_public_references
  s3_bucket_samples           = local.s3_bucket_samples



}
