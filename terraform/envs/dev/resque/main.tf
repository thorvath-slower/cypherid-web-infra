module "resque" {
  source        = "github.com/thorvath-slower/cztack//aws-ecs-job?ref=0fe349fc39bcfeb0e069b4ca45a566751931089a" # cztack v0.104.2
  desired_count = 1
  env           = var.env
  service       = "resque"
  project       = var.project
  owner         = var.owner
  cluster_id    = data.terraform_remote_state.ecs.outputs.cluster_id
  task_role_arn = data.terraform_remote_state.web.outputs.task_role_arn

  manage_task_definition = false
}

module "resque-pipeline-monitor" {
  source        = "github.com/thorvath-slower/cztack//aws-ecs-job?ref=0fe349fc39bcfeb0e069b4ca45a566751931089a" # cztack v0.104.2
  desired_count = 1
  env           = var.env
  service       = "resque-pipeline-monitor"
  project       = var.project
  owner         = var.owner
  cluster_id    = data.terraform_remote_state.ecs.outputs.cluster_id
  task_role_arn = data.terraform_remote_state.web.outputs.task_role_arn

  manage_task_definition = false
}

module "resque-result-monitor" {
  source        = "github.com/thorvath-slower/cztack//aws-ecs-job?ref=0fe349fc39bcfeb0e069b4ca45a566751931089a" # cztack v0.104.2
  desired_count = 1
  env           = var.env
  service       = "resque-result-monitor"
  project       = var.project
  owner         = var.owner
  cluster_id    = data.terraform_remote_state.ecs.outputs.cluster_id
  task_role_arn = data.terraform_remote_state.web.outputs.task_role_arn

  manage_task_definition = false
}

module "resque-scheduler" {
  source        = "github.com/thorvath-slower/cztack//aws-ecs-job?ref=0fe349fc39bcfeb0e069b4ca45a566751931089a" # cztack v0.104.2
  desired_count = 1
  env           = var.env
  service       = "resque-scheduler"
  project       = var.project
  owner         = var.owner
  cluster_id    = data.terraform_remote_state.ecs.outputs.cluster_id
  task_role_arn = data.terraform_remote_state.web.outputs.task_role_arn

  manage_task_definition = false
}

module "shoryuken" {
  source        = "github.com/thorvath-slower/cztack//aws-ecs-job?ref=0fe349fc39bcfeb0e069b4ca45a566751931089a" # cztack v0.104.2
  desired_count = 1
  env           = var.env
  service       = "shoryuken"
  project       = var.project
  owner         = var.owner
  cluster_id    = data.terraform_remote_state.ecs.outputs.cluster_id
  task_role_arn = data.terraform_remote_state.web.outputs.task_role_arn

  manage_task_definition = false
}
