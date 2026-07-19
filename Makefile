.PHONY: help \
	setup install-backend install-web lock-web \
	dev-backend dev-web \
	test test-backend test-web mutation-backend mutation-web \
	lint lint-backend typecheck-backend lint-web lint-env-keys lint-adr-index lint-tdd lint-fix \
	dupe-check dupe-check-html dupe-clean \
	format format-check \
	ci \
	build-web codegen-types \
	migrate migrate-create \
	infra-fmt infra-fmt-check infra-validate-dev infra-validate-stg infra-validate-prod infra-validate \
	clean

# デフォルトターゲット: ヘルプ表示
help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "セットアップ"
	@echo "  setup             初回セットアップ (backend + web を Nix devshell として構築)"
	@echo "  install-backend   Backend 依存を Nix devshell として構築"
	@echo "  install-web       Frontend 依存 (node_modules) を Nix build として構築"
	@echo "  lock-web          web/package-lock.json を更新 (package.json 変更後に実行)"
	@echo ""
	@echo "ローカル開発"
	@echo "  dev-backend       Backend 開発サーバーを起動 (uvicorn / localhost:8000)"
	@echo "  dev-web           Frontend 開発サーバーを起動 (Vite / localhost:5173)"
	@echo ""
	@echo "テスト・リント"
	@echo "  ci                lint + test + build-web を一括実行 (CI 相当)"
	@echo "  test              全テスト (backend + web)"
	@echo "  test-backend      Backend: pytest"
	@echo "  test-web          Frontend: vitest"
	@echo "  lint              全リント (backend + web)"
	@echo "  lint-backend      Backend: ruff check"
	@echo "  typecheck-backend Backend: pyright 型チェック"
	@echo "  lint-web          Frontend: eslint"
	@echo "  lint-env-keys     env名/エラーコードの SSoT drift を検知 (env_keys.py↔.env.example, リテラル参照禁止, errors.py↔errorCodes.ts)"
	@echo "  lint-adr-index    ADR 索引の drift を検知 (docs/adr/README.md↔ADR ファイル)"
	@echo "  lint-tdd          TDD 対象 (mutation スコープ) の実装変更にテスト差分が随伴しているか検知"
	@echo "  mutation-backend  Backend: mutmut (長時間。週次 CI で実行)"
	@echo "  mutation-web      Frontend: Stryker (長時間。レポート: web/reports/mutation/)"
	@echo ""
	@echo "コード重複検知 (jscpd)"
	@echo "  dupe-check        重複検知を実行し report/dupe/ に JSON/HTML/Markdown を出力"
	@echo "  dupe-check-html   同上 (HTML レポート出力後にパスを表示)"
	@echo "  dupe-clean        report/dupe/ を削除"
	@echo "  lint-fix          リント自動修正 (ruff + eslint)"
	@echo "  format            Prettier で整形"
	@echo "  format-check      Prettier チェック"
	@echo ""
	@echo "ビルド"
	@echo "  build-web         Vite ビルド"
	@echo "  codegen-types     OpenAPI から web 型 (src/api/generated.ts) を再生成"
	@echo ""
	@echo "マイグレーション"
	@echo "  migrate           alembic upgrade head"
	@echo "  migrate-create    マイグレーション生成 (例: make migrate-create MSG=\"add user table\")"
	@echo ""
	@echo "インフラ (OpenTofu)"
	@echo "  infra-fmt           tofu fmt -recursive infra"
	@echo "  infra-fmt-check     tofu fmt -check -recursive infra"
	@echo "  infra-validate-dev  dev 環境を validate"
	@echo "  infra-validate-stg  stg 環境を validate"
	@echo "  infra-validate-prod prod 環境を validate"
	@echo "  infra-validate      dev/stg/prod を順に validate"
	@echo ""
	@echo "クリーンアップ"
	@echo "  clean             キャッシュ削除"

# ------------------------------------------------------------------ #
# セットアップ
# ------------------------------------------------------------------ #

setup: install-backend install-web

# 依存の SSoT は backend/pyproject.toml [project.dependencies] + uv.lock。
# Python 依存は Nix devshell（flake.nix の uv2nix build）が提供し、.venv は作らない。
# devshell を一度ビルドしておくことがセットアップに相当する。
install-backend:
	nix develop --command bash -c "python3 --version && echo 'backend 依存は Nix devshell が提供します（.venv 不要）'"

# web の node_modules も Nix build（flake.nix の importNpmLock / 正本は package-lock.json）。
# devshell 突入時に web/node_modules が Nix 成果物への symlink として張られる。
# npm install は使わない。依存を変えたら package.json を編集して make lock-web する。
install-web:
	nix develop --command bash -c "ls web/node_modules > /dev/null && echo 'web 依存は Nix build が提供します（npm install 不要）'"

# node_modules（read-only symlink）を npm に触らせないため一時ディレクトリで lock を解決する
lock-web:
	nix develop --command bash scripts/npm-lock.sh

# ------------------------------------------------------------------ #
# ローカル開発
# ------------------------------------------------------------------ #

dev-backend:
	nix develop --command bash -c "cd backend && uvicorn app.main:app --reload --port 8000"

dev-web:
	nix develop --command bash -c "cd web && npm run dev"

# ------------------------------------------------------------------ #
# テスト・リント
# ------------------------------------------------------------------ #

ci: lint format-check test build-web

test: test-backend test-web

# --cov は pyproject の addopts ではなくここで付与する（mutation テスト導入時の干渉回避）
test-backend:
	nix develop --command bash -c "cd backend && python -m pytest -q --cov=app --cov-report=term-missing tests"

test-web:
	nix develop --command bash -c "cd web && npm test"

lint: lint-backend typecheck-backend lint-web lint-env-keys lint-adr-index lint-tdd

lint-backend:
	nix develop --command bash -c "cd backend && ruff check app tests alembic_migrations"

# Backend 型チェック（pyright）。import 解決は devshell の python（uv2nix build 環境）を
# --pythonpath で明示する（.venv は存在しない）。
# バージョンは CI（.github/workflows/ci.yml）と揃えてピン留めする（drift 防止）。
typecheck-backend:
	nix develop --command bash -c "cd backend && uvx pyright@1.1.411 --pythonpath \"\$$(command -v python3)\" app tests alembic_migrations"

lint-web:
	nix develop --command bash -c "cd web && npm run lint"

# env 名 / エラーコードの SSoT drift を検知
# （env_keys.py↔.env.example 双方向 + リテラル参照禁止 + errors.py↔errorCodes.ts）。
# grep/sed/comm のみに依存するため nix wrap 不要。
lint-env-keys:
	bash scripts/lint-env-keys.sh

# ADR 索引（docs/adr/README.md）↔ ADR ファイルの drift を検知。
# 存在（双方向）・ステータス・見出し番号の突合。bash/grep/sed/comm のみに依存するため
# nix wrap 不要（devshell に無い依存を使わない）。
lint-adr-index:
	bash scripts/lint-adr-index.sh

# TDD 対象（mutation スコープの決定論的ロジック層）の実装変更にテスト差分が
# 随伴しているかを検知。対象 glob は mutation 設定から動的に読み出す。
# bash/git/awk/sed のみに依存するため nix wrap 不要。
lint-tdd:
	bash scripts/lint-tdd.sh

# ミューテーションテスト。フル実行は長時間かかるため通常 CI には含めず、
# 週次の .github/workflows/mutation.yml で実行する。対象は pyproject [tool.mutmut] /
# web/stryker.conf.json を参照。
mutation-backend:
	nix develop --command bash -c "cd backend && python -m mutmut run"

mutation-web:
	nix develop --command bash -c "cd web && npm run test:mutation"

lint-fix:
	nix develop --command bash -c "cd backend && ruff check --fix app tests alembic_migrations"
	nix develop --command bash -c "cd web && npm run lint:fix"

format:
	nix develop --command bash -c "cd web && npm run format"

format-check:
	nix develop --command bash -c "cd web && npm run format:check"

# ------------------------------------------------------------------ #
# コード重複検知 (jscpd)
# ------------------------------------------------------------------ #

# jscpd は npx 経由で実行する（devshell の nodejs を利用）。
# 設定は .jscpd.json、出力は report/dupe/。導入初期は warn-only（threshold=100）。
dupe-check:
	nix develop --command bash -c "mkdir -p report/dupe && npx --yes jscpd@4 --config .jscpd.json"

dupe-check-html:
	nix develop --command bash -c "mkdir -p report/dupe && npx --yes jscpd@4 --config .jscpd.json"
	@echo "HTML レポート: report/dupe/html/index.html"

dupe-clean:
	rm -rf report/dupe

# ------------------------------------------------------------------ #
# ビルド
# ------------------------------------------------------------------ #

build-web:
	nix develop --command bash -c "cd web && npm run build"

# backend の FastAPI OpenAPI スキーマから web の型定義を生成する（型契約）。
# export_openapi.py で backend/openapi.json（gitignore 対象の中間生成物）を出力し、
# gen-types.mjs で web/src/api/generated.ts（コミット対象）を再生成する。
# 正本（app/schemas/ の Pydantic・ルーター定義）を変えたら必ず実行してコミットする
# （CI の codegen-drift ジョブが drift を検証する）。
codegen-types:
	nix develop --command bash -c "set -e; cd backend && python scripts/export_openapi.py && cd ../web && node scripts/gen-types.mjs"

# ------------------------------------------------------------------ #
# マイグレーション
# ------------------------------------------------------------------ #

migrate:
	nix develop --command bash -c "cd backend && alembic upgrade head"

migrate-create:
	@if [ -z "$(MSG)" ]; then echo "エラー: MSG を指定してください (例: make migrate-create MSG=\"add user table\")"; exit 1; fi
	nix develop --command bash -c "cd backend && alembic revision --autogenerate -m \"$(MSG)\""

# ------------------------------------------------------------------ #
# インフラ (OpenTofu)
# ------------------------------------------------------------------ #

infra-fmt:
	nix develop --command tofu fmt -recursive infra

infra-fmt-check:
	nix develop --command tofu fmt -check -recursive infra

infra-validate-dev:
	nix develop --command bash -c "tofu -chdir=infra/environments/dev init -backend=false -input=false && tofu -chdir=infra/environments/dev validate"

infra-validate-stg:
	nix develop --command bash -c "tofu -chdir=infra/environments/stg init -backend=false -input=false && tofu -chdir=infra/environments/stg validate"

infra-validate-prod:
	nix develop --command bash -c "tofu -chdir=infra/environments/prod init -backend=false -input=false && tofu -chdir=infra/environments/prod validate"

infra-validate: infra-validate-dev infra-validate-stg infra-validate-prod

# ------------------------------------------------------------------ #
# クリーンアップ
# ------------------------------------------------------------------ #

clean:
	rm -rf backend/.pytest_cache backend/.ruff_cache
	find . -type d -name __pycache__ -not -path "./web/node_modules/*" | xargs rm -rf
