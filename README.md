# katagami（型紙）

SaaS 開発の規律を機械検証で守る「縦串」テンプレートリファレンス。

型紙 = 1 枚の型から各自のプロダクトを仕立てるための下敷き。特定ドメインの学習用リポジトリではなく、
横断規律（環境変数管理・エラー契約・型契約・品質ゲート等）を CI で機械検証する仕組みそのものを提供する。
サンプルドメイン（Note）は縦串の貫通例であり、置き換える前提。

## 縦串一覧（目次）

| 縦串 | 内容 | 正本 | 機械検証 |
| --- | --- | --- | --- |
| 開発環境の Nix 一元管理 | toolchain・Python 依存（uv2nix）・node_modules（importNpmLock）を lock 正本の Nix build に統一 | `flake.nix` / `uv.lock` / `package-lock.json`（[ADR-0001](docs/adr/0001-nix-managed-toolchain.md)） | CI の lock drift 検証 |
| env_keys 規律 | 環境変数名の SSoT。リテラル参照禁止・downstream（.env.example / cloud_run）突合 | `backend/app/core/env_keys.py` | `make lint-env-keys` |
| エラー契約 | 全 API エラーを AppErrorResponse 形へ正規化。コード集合を BE↔FE で同期 | `backend/app/core/errors.py` | `make lint-env-keys`（集合一致） |
| 型契約（OpenAPI codegen） | Pydantic schema → `web/src/api/generated.ts` を機械生成 | `backend/app/schemas/` | CI `codegen-drift` |
| DB 基盤 | SQLAlchemy + alembic。スキーマ正本はマイグレーション。`DATABASE_URL` でパラメータ化 | `backend/alembic_migrations/` | `make migrate` + 適用テスト |
| 非同期タスク基盤 | 状態遷移（pending→processing→completed/retrying/dead_letter）+ ハンドラレジストリ | `backend/app/services/tasks/` | 状態遷移テスト |
| 品質ゲート | DRY 検知（jscpd）/ ミューテーション（mutmut / Stryker）/ TDD 随伴 lint | `.jscpd.json` / `[tool.mutmut]` / `stryker.conf.json` | `make dupe-check` / 週次 CI / `make lint-tdd` |
| infra（OpenTofu） | stack module 集約。環境差分は tfvars のみ。env 名は env_keys と突合 | `infra/modules/katagami_stack/` | `make infra-validate` / CI |
| ADR 運用 | 意思決定の記録。索引 ↔ ファイルの drift を機械検証 | `docs/adr/README.md` | `make lint-adr-index` |
| AI 協働規律 | 実行方法（Nix 経由必須）・コミット/PR フロー・scoped rules | `.claude/CLAUDE.md` + `.claude/rules/` | —（運用） |

## 構成

| パス | 内容 |
| --- | --- |
| `flake.nix` | 開発環境の SSoT。backend Python 依存は uv2nix、web node_modules は importNpmLock で Nix build（.venv / npm install 不要） |
| `backend/` | FastAPI アプリ。依存の正本は `pyproject.toml` + `uv.lock`（全依存 `==` 固定） |
| `web/` | React + Vite + TypeScript アプリ。依存の正本は `package.json` + `package-lock.json`（更新は `make lock-web`） |
| `infra/` | OpenTofu（stack module + dev/stg/prod） |
| `docs/adr/` | ADR（テンプレート + 索引） |
| `Makefile` | タスクランナー。`make help` で一覧 |
| `.github/workflows/` | CI（lint + typecheck + test + build + codegen/lock drift + jscpd + OpenTofu + 週次 mutation） |

## クイックスタート

```bash
# 前提: Nix（flakes 有効）
nix develop        # 開発環境に入る
make setup         # 初回セットアップ
make ci            # lint + format-check + test + build を一括実行（CI 相当）

make dev-backend   # API 起動（localhost:8000）
make dev-web       # Vite 起動（localhost:5173）
```

## サンプルドメイン（置き換え対象）

`Note`（メモ CRUD + 決定論的サマリ生成の非同期タスク）が全縦串を貫通している。
自分のプロダクトを仕立てる際は、`app/models/note.py` / `app/schemas/note.py` /
`app/routers/notes.py` / `app/services/notes/` / `app/services/tasks/handlers/note_summarize.py` /
`web/src/api/notes.ts` を自ドメインに置き換え、同じ縦串（マイグレーション・codegen・
エラー契約・テスト・mutation スコープ）を通すことがそのまま開発規律のトレースになる。
