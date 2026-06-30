module "policy-params-service" {
  source    = "github.com/thorvath-slower/cztack//aws-params-reader-policy?ref=ad3cae93e104cf399f5c24ffd4f1096143202907" # cztack v0.41.0
  env       = var.env
  project   = var.project
  region    = var.region
  role_name = module.ecs-role.name

  service = var.component
}

module "ecs-role" {
  source  = "github.com/thorvath-slower/cztack//aws-iam-ecs-task-role?ref=ad3cae93e104cf399f5c24ffd4f1096143202907" # cztack v0.41.0
  project = var.project
  env     = var.env
  owner   = var.owner

  service = var.component
}
