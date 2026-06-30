locals {
  name = "${var.tags.project}-${var.tags.env}-${var.tags.service}"
}

resource "kubernetes_deployment_v1" "fivetran_ssh" {
  metadata {
    name      = local.name
    namespace = data.terraform_remote_state.happy.outputs.namespace
    labels = {
      app = local.name
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = local.name
      }
    }

    template {
      metadata {
        labels = {
          app = local.name
        }
      }

      spec {
        node_selector = {
          "kubernetes.io/arch" = "amd64"
        }

        # legacy db
        container {
          name  = "${local.name}-legacy"
          image = "732052188396.dkr.ecr.us-west-2.amazonaws.com/czid-fivetran-ssh:latest"

          port {
            container_port = 80
          }

          env {
            name  = "SSH_HIGH_PORT"
            value = "13307"
          }

          env {
            name  = "RDS_PORT"
            value = "3306"
          }

          env {
            name  = "FIVETRAN_SSH_SERVER"
            value = "34.48.124.245"
          }

          volume_mount {
            name       = "fivetran-private-key"
            mount_path = "/var/secrets"
          }
        }

        volume {
          name = "fivetran-private-key"

          secret {
            secret_name = module.parameters.secret_name
          }
        }
      }
    }
  }
}

module "parameters" {
  source = "../../../modules/kubernetes-secret-from-aws-param-v0.395.0"

  project = var.tags.project
  env     = var.tags.env
  service = var.tags.service
  owner   = var.tags.owner

  aws_ssm_iam_role_name = data.terraform_remote_state.k8s-core.outputs.aws_ssm_iam_role_name

  namespace   = data.terraform_remote_state.happy.outputs.namespace
  secret_name = "fivetran-private-key-new"
}
