#!/usr/bin/env bash
# 領域跨ぎの SSoT drift を検知する。
#
# 背景:
#   環境変数名は「正本（backend）を変えたのに downstream（.env.example 等）の追従を
#   忘れる」事故が起きやすい。言語境界（Python / dotenv / YAML）上リテラルの複製を
#   消せないため、複製を消す代わりに「複製が正本と一致しているか」を機械検証する。
#
# 検証内容:
#   (1) env 名（正方向）: backend/app/core/env_keys.py の定数値（= 実 env 名）が
#       .env.example にすべて存在するか（ALLOWLIST で内部フラグ等を除外）。
#       rename / 追加時の同期忘れを CI で止める。
#   (2) env 名（逆方向）: .env.example に書かれた env 名がすべて env_keys.py に
#       存在するか。rename / 削除時に旧名が残留する drift と typo を検知する。
#   (3) リテラル参照禁止: backend/app が os.getenv("XXX") / os.environ["XXX"] /
#       os.environ.get("XXX") の文字列リテラルで env を参照していないか
#       （env_keys 定数経由を機械強制する）。
#   (4) エラーコード: backend/app/core/errors.py の ErrorCode 値集合と
#       web/src/constants/errorCodes.ts の ERROR_CODES が完全一致するか。
#       FE 側の型検査（Record<ErrorCodeKey,...>）は FE 内で完結するため、
#       BE が新コードを追加して FE 未反映の drift は型エラーにならない。それを補う。
#
# 将来の拡張（対応する縦串の導入時に追加する）:
#   - docker-compose.yml / IaC（cloud_run 等）の env block との突合
#
# 正本:
#   - env 名:       backend/app/core/env_keys.py
#   - エラーコード: backend/app/core/errors.py の ErrorCode
set -euo pipefail

cd "$(dirname "$0")/.."

ENV_KEYS="backend/app/core/env_keys.py"
ENV_EXAMPLE=".env.example"
ERRORS_PY="backend/app/core/errors.py"
ERROR_CODES_TS="web/src/constants/errorCodes.ts"

# .env.example に載せない env_keys 定数（設定ではなくランタイム内部フラグ等）。
# 現状は無し。追加する場合は理由をコメントで残すこと。
ENV_EXAMPLE_ALLOWLIST=$(printf '%s\n' \
  | sort -u)

fail=0

if [ ! -f "$ENV_EXAMPLE" ]; then
  echo "ERROR: $ENV_EXAMPLE が存在しません。" >&2
  exit 1
fi

# ── (1) env_keys.py ⊆ .env.example ─────────────────────────────────────────
# 抽出は grep -E / sed -E のみで行う（PCRE / ripgrep に依存しない）。
# env_keys.py からは定数の「文字列値」（= 実 env 名）を取る。symbol 名ではなく値が
# downstream の env 名になるため、`NAME = "VALUE"` の VALUE 側を比較対象にする
# （symbol だけ rename しても誤検知せず、値だけ変えた drift も取りこぼさない）。
env_names=$(grep -E '^[A-Z_]+[[:space:]]*=[[:space:]]*"[^"]+"' "$ENV_KEYS" \
  | sed -E 's/^[A-Z_]+[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/' | sort -u)

example_names=$(grep -E '^[A-Z_]+=' "$ENV_EXAMPLE" | sed -E 's/^([A-Z_]+)=.*/\1/' | sort -u)

expected_in_example=$(comm -23 <(printf '%s\n' "$env_names") <(printf '%s\n' "$ENV_EXAMPLE_ALLOWLIST"))
missing_in_example=$(comm -23 <(printf '%s\n' "$expected_in_example") <(printf '%s\n' "$example_names"))

if [ -n "$missing_in_example" ]; then
  echo "ERROR: 次の env 名が $ENV_KEYS にあるが $ENV_EXAMPLE に未記載です:" >&2
  printf '  - %s\n' $missing_in_example >&2
  echo "" >&2
  echo "$ENV_KEYS の定数を rename / 追加したら $ENV_EXAMPLE も追従してください。" >&2
  echo "意図的に載せない場合は scripts/lint-env-keys.sh の ENV_EXAMPLE_ALLOWLIST に追記。" >&2
  echo "" >&2
  fail=1
fi

# ── (2) 逆方向: .env.example の env 名 ⊆ env_keys.py ───────────────────────
unknown_in_example=$(comm -23 <(printf '%s\n' "$example_names") <(printf '%s\n' "$env_names"))

if [ -n "$unknown_in_example" ]; then
  echo "ERROR: $ENV_KEYS に存在しない env 名が $ENV_EXAMPLE に残っています:" >&2
  printf '  - %s\n' $unknown_in_example >&2
  echo "" >&2
  echo "rename / 削除した env 名の旧名残留か typo です。$ENV_EXAMPLE 側を追従してください。" >&2
  echo "" >&2
  fail=1
fi

# ── (3) backend のリテラル env 参照禁止（env_keys 定数経由を強制） ──────────
# env_keys.py 自身は docstring にリテラル例を含むため除外する。
literal_refs=$(grep -rnE 'os\.(getenv|environ\.get)\([[:space:]]*"|os\.environ\[[[:space:]]*"' \
  backend/app --include='*.py' | grep -v 'app/core/env_keys\.py' || true)

if [ -n "$literal_refs" ]; then
  echo "ERROR: backend/app に文字列リテラルでの env 参照があります:" >&2
  printf '%s\n' "$literal_refs" | sed 's/^/  /' >&2
  echo "" >&2
  echo "from app.core import env_keys した上で os.getenv(env_keys.XXX) を使ってください。" >&2
  echo "" >&2
  fail=1
fi

# ── (4) errors.py ErrorCode == errorCodes.ts ERROR_CODES ──────────────────
be_codes=$(grep -E '^[[:space:]]+[A-Z_]+[[:space:]]*=[[:space:]]*"[A-Z_]+"' "$ERRORS_PY" \
  | sed -E 's/.*=[[:space:]]*"([A-Z_]+)".*/\1/' | sort -u)
fe_codes=$(grep -E '^[[:space:]]+"[A-Z_]+",' "$ERROR_CODES_TS" \
  | sed -E 's/.*"([A-Z_]+)".*/\1/' | sort -u)

be_only=$(comm -23 <(printf '%s\n' "$be_codes") <(printf '%s\n' "$fe_codes"))
fe_only=$(comm -13 <(printf '%s\n' "$be_codes") <(printf '%s\n' "$fe_codes"))

if [ -n "$be_only" ] || [ -n "$fe_only" ]; then
  echo "ERROR: ErrorCode の集合が BE と FE で一致しません。" >&2
  if [ -n "$be_only" ]; then
    echo "  $ERRORS_PY にあるが $ERROR_CODES_TS に無い:" >&2
    printf '    - %s\n' $be_only >&2
  fi
  if [ -n "$fe_only" ]; then
    echo "  $ERROR_CODES_TS にあるが $ERRORS_PY に無い:" >&2
    printf '    - %s\n' $fe_only >&2
  fi
  echo "" >&2
  echo "errors.py の ErrorCode を正本に、errorCodes.ts と errorMessages.ts を追従してください。" >&2
  echo "" >&2
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "lint-env-keys: OK（env 名 .env.example・リテラル参照・ErrorCode の SSoT drift なし）"
