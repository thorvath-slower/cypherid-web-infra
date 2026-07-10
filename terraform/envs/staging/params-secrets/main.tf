module "aws-params-secrets-setup" {
  source     = "git::https://github.com/thorvath-slower/seqtoid-ssot-infra.git//modules/cztack/aws-params-secrets-setup?ref=5fae7f3216c66d5eaf85912b107df25627c3703f" # cztack v0.104.2
  alias_name = local.alias_name
  env        = local.env
  owner      = local.owner
  project    = local.project
  service    = local.service



}
