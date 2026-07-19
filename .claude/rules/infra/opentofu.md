---
paths:
  - infra/**
---

# OpenTofu ルール

## 構成の原則

- **module 呼び出しは stack module（`infra/modules/katagami_stack`）に集約する。**
  環境（`infra/environments/{dev,stg,prod}`）の `main.tf` は stack module の呼び出しだけを持ち、
  全環境で同一内容を保つ。環境差分は `terraform.tfvars`（gitignore 対象。テンプレートは
  `terraform.tfvars.example`）でのみ表現する
- 新しいリソース種別は `infra/modules/<name>/` に module として切り、stack module から呼ぶ
- provider のバージョンは `versions.tf` で `~>` 制約を付ける

## 環境変数の同期

- `infra/modules/cloud_run/main.tf` に書く env 名の正本は `backend/app/core/env_keys.py`。
  逆方向（tf → env_keys）の drift は `make lint-env-keys`（CI 含む）が機械検証する
- 秘密情報は Secret Manager コンテナ（`locals.required_secret_env`）経由で注入し、
  平文の `value` に書かない。tf の variable に持たせる場合は `sensitive = true` を必ず付与する

## 検証・適用

- 変更したら `make infra-fmt` で整形し、`make infra-validate` を通してから PR を出す
  （CI の OpenTofu CI ジョブが fmt-check + validate を検証する）
- **`tofu apply -auto-approve` をローカルから本番環境に直接流さない。** plan を確認してから apply する
- `lifecycle { prevent_destroy = true }` 付きリソースへの破壊的変更は実行前に必ず確認する
- CI は静的検証のみ（apply しない）。クラウド認証情報を CI に置く場合は別途 ADR で判断する

## コスト

- Cloud Run は `max_instance_count = 1 / min_instance_count = 0`（コスト最優先）を既定とする。
  スケール要件が出たら module の変数化から始める
- Artifact Registry はクリーンアップポリシー（タグ付き最新 3 件保持・untagged 1 日で削除）を維持する
