
module "ecrs" {
  for_each = var.ecr_repos
  source   = "github.com/thorvath-slower/cztack//aws-ecr-repo?ref=0fe349fc39bcfeb0e069b4ca45a566751931089a" # cztack v0.104.2

  name       = each.value["name"]
  read_arns  = each.value["read_arns"]
  write_arns = each.value["write_arns"]

  tag_mutability = each.value["tag_mutability"] == null ? true : each.value["tag_mutability"]
  scan_on_push   = each.value["scan_on_push"] == null ? false : each.value["scan_on_push"]

  tags = var.tags
}
