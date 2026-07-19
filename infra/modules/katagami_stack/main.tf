# --------------------------------------------------------------------
# katagami_stack: environments/<env> から呼ばれる stack composition module
# 3 つの module（service_account / artifact_registry / cloud_run）を内包し、
# 必要な GCP API も同じ場所で有効化する。
#
# 環境（dev/stg/prod）の main.tf は本 module の呼び出しだけを持ち、
# 環境差分は terraform.tfvars 経由で渡す（環境間で main.tf を複製しても
# 差分が出ない構造を守る）。
# --------------------------------------------------------------------

locals {
  stack_name = "${var.app_name}-${var.environment}"

  # Cloud Run / Artifact Registry / Secret Manager / Monitoring / Logging の依存 API
  required_apis = [
    "artifactregistry.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
  ]
}

# 必要な GCP API の有効化（destroy 時には無効化しない）
resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  project                    = var.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}

module "service_account" {
  source = "../service_account"

  project_id                     = var.project_id
  stack_name                     = local.stack_name
  deployer_service_account_email = var.deployer_service_account_email

  depends_on = [google_project_service.apis]
}

module "artifact_registry" {
  source = "../artifact_registry"

  project_id = var.project_id
  region     = var.region
  stack_name = local.stack_name

  depends_on = [google_project_service.apis]
}

module "cloud_run" {
  source = "../cloud_run"

  project_id            = var.project_id
  region                = var.region
  stack_name            = local.stack_name
  service_account_email = module.service_account.email
  cors_origins          = var.cors_origins

  depends_on = [google_project_service.apis]
}
