# Cloud Run ランタイム用のサービスアカウント。
# 付与ロールは最小権限を維持する。新規ロールを足す場合は
# 「なぜそのロールが必要か」をコメントで残すこと（.claude/rules/security.md）。

resource "google_service_account" "app" {
  project      = var.project_id
  account_id   = "${var.stack_name}-run"
  display_name = "${var.stack_name} Cloud Run runtime SA"
}

# デプロイヤー SA（CI）がランタイム SA として Cloud Run をデプロイするための actAs
resource "google_service_account_iam_member" "deployer_act_as" {
  count = var.deployer_service_account_email != "" ? 1 : 0

  service_account_id = google_service_account.app.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.deployer_service_account_email}"
}

# デプロイヤー SA が Artifact Registry へイメージを push するため
resource "google_project_iam_member" "deployer_artifact_registry_writer" {
  count = var.deployer_service_account_email != "" ? 1 : 0

  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${var.deployer_service_account_email}"
}

# デプロイヤー SA が Cloud Run のリビジョンを更新するため
resource "google_project_iam_member" "deployer_run_developer" {
  count = var.deployer_service_account_email != "" ? 1 : 0

  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${var.deployer_service_account_email}"
}
