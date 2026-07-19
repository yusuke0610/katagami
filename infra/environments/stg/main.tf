provider "google" {
  project = var.project_id
  region  = var.region
}

# --------------------------------------------------------------------
# stack composition（全環境共通）
# 各 module の呼び出しは ../../modules/katagami_stack に集約されている。
# 環境差分は terraform.tfvars 経由で渡し、この main.tf 自体は全環境で共有する
# （dev/stg/prod の main.tf は同一内容を保つこと）。
# --------------------------------------------------------------------
module "katagami_stack" {
  source = "../../modules/katagami_stack"

  environment                    = var.environment
  project_id                     = var.project_id
  app_name                       = var.app_name
  region                         = var.region
  deployer_service_account_email = var.deployer_service_account_email

  cors_origins = var.cors_origins
}
