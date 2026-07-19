# Cloud Run サービス（backend API）。
#
# 環境変数の同期規律:
#   ここに書く env 名の正本は backend/app/core/env_keys.py。
#   本ファイルに env_keys に無い名前が現れると make lint-env-keys（CI 含む）が fail する。
#   秘密情報は Secret Manager コンテナ経由（locals.required_secret_env）で注入し、
#   平文の value には置かない。

locals {
  # Secret Manager に作るシークレットコンテナ（値の投入は手動 / CI）
  secret_names = [
    "database-url",
  ]

  # 環境変数名（env_keys 準拠）→ シークレット名
  required_secret_env = {
    DATABASE_URL = "database-url"
  }

  # 初回 apply 時のブートストラップ用イメージ。
  # Artifact Registry にアプリイメージが push される前でも Cloud Run リソース作成を
  # 成立させるための公開 hello イメージ。以後は ignore_changes により CI のデプロイが
  # image を上書きする。
  bootstrap_image = "us-docker.pkg.dev/cloudrun/container/hello:latest"
}

resource "google_secret_manager_secret" "app" {
  for_each  = toset(local.secret_names)
  project   = var.project_id
  secret_id = "${var.stack_name}-${each.key}"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_member" "app" {
  for_each  = google_secret_manager_secret.app
  project   = var.project_id
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.service_account_email}"
}

resource "google_cloud_run_v2_service" "app" {
  project             = var.project_id
  name                = var.stack_name
  location            = var.region
  deletion_protection = false

  template {
    service_account = var.service_account_email

    containers {
      image = local.bootstrap_image

      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
      }
      ports {
        container_port = 8000
      }

      env {
        name  = "CORS_ORIGINS"
        value = var.cors_origins
      }

      dynamic "env" {
        for_each = local.required_secret_env
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.app[env.value].secret_id
              version = "latest"
            }
          }
        }
      }
    }

    max_instance_request_concurrency = 80

    # コスト最優先の既定値（個人開発規模）。スケールが必要になったら
    # 環境ごとの tfvars でなく本 module の変数化から始めること
    scaling {
      max_instance_count = 1
      min_instance_count = 0
    }
  }

  lifecycle {
    # CI が新リビジョンをデプロイするため、後続 apply で bootstrap イメージへ
    # 巻き戻さないよう image の差分は無視する
    ignore_changes = [template[0].containers[0].image]
  }
}

resource "google_cloud_run_v2_service_iam_member" "public_access" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
