# state 保存先の GCS バケット。事前に手動作成しておくこと（versioning 有効を推奨）。
# バケット名はプロジェクトに合わせて置き換える。
terraform {
  backend "gcs" {
    bucket = "katagami-tfstate-dev"
    prefix = "terraform/state"
  }
}
