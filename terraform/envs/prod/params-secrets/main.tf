module "aws-params-secrets-setup" {
  source     = "github.com/thorvath-slower/cztack//aws-params-secrets-setup?ref=0fe349fc39bcfeb0e069b4ca45a566751931089a" # cztack v0.104.2
  alias_name = local.alias_name
  env        = local.env
  owner      = local.owner
  project    = local.project
  service    = local.service



}
