module "dynamodb_writer" {
  source    = "github.com/thorvath-slower/cztack//aws-iam-policy-dynamodb-rw?ref=0fe349fc39bcfeb0e069b4ca45a566751931089a" # cztack v0.104.2
  table_arn = var.dynamodb_table_arn
  role_name = var.gh_actions_role_name
  tags      = var.tags
}
