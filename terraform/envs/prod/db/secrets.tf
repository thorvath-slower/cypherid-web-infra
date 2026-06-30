module "db_password" {
  source  = "github.com/thorvath-slower/cztack//aws-param?ref=b26586a9707db37d94ac3bfb2e2a2fb48978d4a6" # cztack v0.26.1
  project = var.project
  env     = var.env
  service = "web"
  name    = "db_password"
}
