module "otel" {
  source = "../../../modules/otel-collector"

  env     = var.env
  project = var.project
  owner   = var.owner
  region  = var.region

  cluster_id = data.terraform_remote_state.ecs.outputs.cluster_id
  vpc_id     = data.terraform_remote_state.cloud-env.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.cloud-env.outputs.private_subnets

  # Allow OTLP from anything in the VPC (the app/worker/pipeline tasks).
  app_ingress_cidrs = [data.terraform_remote_state.cloud-env.outputs.vpc_cidr_block]

  # Pin the collector image by digest for reproducibility (dev override of the module default).
  collector_image = "public.ecr.aws/aws-observability/aws-otel-collector:v0.43.3"

  tags = var.tags
}
