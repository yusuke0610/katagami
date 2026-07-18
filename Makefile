.PHONY: help \
	setup install-backend install-web lock-web \
	dev-backend dev-web \
	test test-backend test-web \
	lint lint-backend typecheck-backend lint-web lint-fix \
	format format-check \
	ci \
	build-web \
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
	@echo "  lint-fix          リント自動修正 (ruff + eslint)"
	@echo "  format            Prettier で整形"
	@echo "  format-check      Prettier チェック"
	@echo ""
	@echo "ビルド"
	@echo "  build-web         Vite ビルド"
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

lint: lint-backend typecheck-backend lint-web

lint-backend:
	nix develop --command bash -c "cd backend && ruff check app tests"

# Backend 型チェック（pyright）。import 解決は devshell の python（uv2nix build 環境）を
# --pythonpath で明示する（.venv は存在しない）。
# バージョンは CI（.github/workflows/ci.yml）と揃えてピン留めする（drift 防止）。
typecheck-backend:
	nix develop --command bash -c "cd backend && uvx pyright@1.1.411 --pythonpath \"\$$(command -v python3)\" app tests"

lint-web:
	nix develop --command bash -c "cd web && npm run lint"

lint-fix:
	nix develop --command bash -c "cd backend && ruff check --fix app tests"
	nix develop --command bash -c "cd web && npm run lint:fix"

format:
	nix develop --command bash -c "cd web && npm run format"

format-check:
	nix develop --command bash -c "cd web && npm run format:check"

# ------------------------------------------------------------------ #
# ビルド
# ------------------------------------------------------------------ #

build-web:
	nix develop --command bash -c "cd web && npm run build"

# ------------------------------------------------------------------ #
# クリーンアップ
# ------------------------------------------------------------------ #

clean:
	rm -rf backend/.pytest_cache backend/.ruff_cache
	find . -type d -name __pycache__ -not -path "./web/node_modules/*" | xargs rm -rf
