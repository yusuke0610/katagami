"""環境変数名の SSoT 定義モジュール。

本モジュールは backend / ローカル環境定義を跨いで使われる環境変数名
（文字列リテラル）を Python 定数として集約する。

## SSoT 違反の背景

同じ環境変数名が複数箇所（backend の `os.getenv("XXX")`、`.env.example`、
将来的には docker-compose / IaC の env block）にリテラルとして独立に書かれると、
rename 時に同期忘れの事故が起きやすい。言語境界上リテラルの複製は消せないため、
複製を消す代わりに「複製が正本と一致しているか」を機械検証する。

## 運用ルール

- backend 内では本モジュールの定数を参照する（`os.getenv("XXX")` ではなく
  `os.getenv(env_keys.XXX)`）
- 新規環境変数を追加する場合は、まず本モジュールに定数を追加する
- 環境変数名を rename / 追加する場合:
  1. 本モジュールの定数値を更新
  2. `.env.example` を追従（用途コメント付き）
  3. 注入経路（docker-compose / IaC）を導入済みならそれらも追従

## drift 検知（自動）

`scripts/lint-env-keys.sh`（`make lint-env-keys` / CI）が以下を機械検証する:

- 本モジュールの定数値が `.env.example` にすべて存在するか
  （意図的に載せない内部フラグ等は同スクリプトの ENV_EXAMPLE_ALLOWLIST に明示）
- `.env.example` に書かれた env 名がすべて本モジュールに存在するか
  （rename / 削除時の旧名残留・typo を検知）
- backend/app が `os.getenv("XXX")` 等の文字列リテラルで env を参照していないか
  （本モジュールの定数経由を機械強制する）
"""

# --- アプリケーション識別 ---

APP_VERSION = "APP_VERSION"

# --- データベース ---

DATABASE_URL = "DATABASE_URL"

# --- CORS ---

CORS_ORIGINS = "CORS_ORIGINS"
