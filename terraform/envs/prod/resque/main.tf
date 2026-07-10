module "resque" {
  source        = "git::https://github.com/thorvath-slower/seqtoid-ssot-infra.git//modules/cztack/aws-ecs-job?ref=5fae7f3216c66d5eaf85912b107df25627c3703f" # cztack v0.104.2
  desired_count = 10
  env           = var.env
  service       = "resque"
  project       = var.project
  owner         = var.owner
  cluster_id    = data.terraform_remote_state.ecs.outputs.cluster_id
  task_role_arn = data.terraform_remote_state.web.outputs.task_role_arn

  manage_task_definition = false
}

module "resque-pipeline-monitor" {
  source        = "git::https://github.com/thorvath-slower/seqtoid-ssot-infra.git//modules/cztack/aws-ecs-job?ref=5fae7f3216c66d5eaf85912b107df25627c3703f" # cztack v0.104.2
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
  source        = "git::https://github.com/thorvath-slower/seqtoid-ssot-infra.git//modules/cztack/aws-ecs-job?ref=5fae7f3216c66d5eaf85912b107df25627c3703f" # cztack v0.104.2
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
  source        = "git::https://github.com/thorvath-slower/seqtoid-ssot-infra.git//modules/cztack/aws-ecs-job?ref=5fae7f3216c66d5eaf85912b107df25627c3703f" # cztack v0.104.2
  desired_count = 1
  env           = var.env
  service       = "resque-scheduler"
  project       = var.project
  owner         = var.owner
  cluster_id    = data.terraform_remote_state.ecs.outputs.cluster_id
  task_role_arn = data.terraform_remote_state.web.outputs.task_role_arn

  manage_task_definition = false
}
