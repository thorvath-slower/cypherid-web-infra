# module "logs" {
#   source  = "github.com/thorvath-slower/cztack//aws-cloudwatch-log-group?ref=ad3cae93e104cf399f5c24ffd4f1096143202907" # cztack v0.41.0
#   project = var.project
#   env     = var.env
#   service = var.component
#   owner   = var.owner
# }
#
# data "template_file" "task_definition" {
#   template = file("${path.module}/templates/fivetran-ssh.json")
#
#   vars = {
#     account_id                       = var.aws_accounts.idseq-prod
#     env                              = var.env
#     region                           = var.region
#     aws_cloudwatch_log_group         = module.logs.name
#     aws_cloudwatch_log_stream_prefix = var.component
#   }
# }
#
# module "service_fivetran" {
#   source = "github.com/thorvath-slower/cztack//aws-ecs-job?ref=ad3cae93e104cf399f5c24ffd4f1096143202907" # cztack v0.41.0
#
#   env     = var.env
#   project = var.project
#   service = var.component
#   owner   = var.owner
#
#   desired_count = "1"
#   cluster_id    = data.terraform_remote_state.ecs.outputs.cluster_id
#   task_role_arn = module.ecs-role.arn
#
#   task_definition = data.template_file.task_definition.rendered
# }
#
# module "web-service-params" {
#   source  = "github.com/thorvath-slower/cztack//aws-ssm-params-writer?ref=ad3cae93e104cf399f5c24ffd4f1096143202907" # cztack v0.41.0
#   project = var.project
#   env     = var.env
#   service = var.component
#   owner   = var.owner
#
#   parameters = {
#     RDS_WRITER_DNS      = data.terraform_remote_state.db.outputs.db_instance_address
#     FIVETRAN_SSH_SERVER = "34.48.124.245"
#     # There is parameter manually provided (/idseq-prod-fivetran-ssh/fivetran_private_key)
#     # FIVETRAN_PRIVATE_KEY = (
#     #    according to this link: (https://fivetran.com/docs/databases/connection-options#reversesshtunnel)
#     #    this is the private part of a SSH key pair created by CZI, and the public part of the key
#     #    apparently was manually provided by CZI to Fivetran via technical support.
#     # )
#   }
# }
