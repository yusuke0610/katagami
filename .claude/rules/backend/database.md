---
paths:
  - backend/**
---

# Database ルール

## スキーマの正本は alembic マイグレーション

- テーブル定義の変更（モデルの追加・カラム変更）をしたら、同じ PR で
  `make migrate-create MSG="..."` によるマイグレーションを必ず随伴させる
- 本番経路で `Base.metadata.create_all` を使わない（スキーマの正本が二重化する）。
  テストでの利用は可
- 新しいモデルモジュールを追加したら `app/models/__init__.py` で import する
  （alembic の autogenerate 対象に載せるため）

## セッション管理

- ルーターでは FastAPI dependency（`app.db.get_db`）経由でセッションを受け取る。
  自前で `SessionLocal()` を開かない（クローズ漏れの温床）
- `IntegrityError` を握って再 SELECT する場合、結果が `None` の可能性を必ず判定する。
  `None` をそのまま返すと呼び出し側で属性参照エラーになり原因が遠くなる。
  想定外なら `RuntimeError` を raise して即時に落とす

## 接続 URL

- 接続 URL は `DATABASE_URL`（正本: `app/core/env_keys.py`）で注入する。既定はローカル SQLite
- 別 RDBMS へ差し替える場合は `app/db/database.py` の URL / engine オプションだけが
  差分になるよう、他レイヤに方言依存を漏らさない

## テスト

- DB はモックせず、テスト用の一時 SQLite（`tests/conftest.py` が設定）を使う
- マイグレーションの適用経路は `tests/test_db.py`（subprocess で `alembic upgrade head`）が
  検証する。env.py の配線を変えたらこのテストを必ず回す
