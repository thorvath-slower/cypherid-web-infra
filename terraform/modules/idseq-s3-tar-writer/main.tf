module "aws-ecr-repo" {
  source = "github.com/thorvath-slower/cztack//aws-ecr-repo?ref=0fe349fc39bcfeb0e069b4ca45a566751931089a" # cztack v0.104.2

  force_delete    = local.force_delete
  max_image_count = var.max_image_count
  name            = var.ecr_repo_name
  tags            = var.tags
}

resource "terraform_data" "build_push_docker_img" {
  triggers_replace = local.docker_img_src_sha256
  provisioner "local-exec" {
    command = local.docker_build_cmd
  }
}
