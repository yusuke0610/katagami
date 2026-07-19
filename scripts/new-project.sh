#!/usr/bin/env bash
# katagami テンプレートから新しいプロジェクトを生成する（ADR-0002）。
#
# 配布は Nix flake app 経由（インストール不要 / ツールは runtimeInputs で固定）:
#   nix run github:yusuke0610/katagami#new -- <app名> [出力先ディレクトリ]
#
# 生成方式:
#   テンプレート内のアプリ名はすべて TEMPLATE_TOKEN（このリポジトリでは "katagami"）で
#   統一されている前提で、ファイル内容・ファイル/ディレクトリ名の両方を <app名> へ
#   一括置換する。jinja 等のプレースホルダを埋め込まないため、テンプレート自体が
#   常に実行可能（make ci green）なまま維持される。
#   lock ファイル（uv.lock / package-lock.json）内の名前も同時に置換されるため、
#   生成直後から CI の lock drift 検証が green になる。
#
# 注意:
#   sed は GNU sed（gnused）前提。flake app 経由の実行では Nix が供給する。
set -euo pipefail

TEMPLATE_TOKEN="katagami"
# flake app 実行時は KATAGAMI_TEMPLATE_ROOT（= flake の self / store パス）が渡される。
# 直接実行時はこのスクリプトの親ディレクトリ（作業コピー）をテンプレートにする。
TEMPLATE_ROOT="${KATAGAMI_TEMPLATE_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

usage() {
  cat <<USAGE
使い方: nix run github:yusuke0610/${TEMPLATE_TOKEN}#new -- <app名> [出力先ディレクトリ] [--template default]

  app名               生成するプロジェクト名（小文字英数字とハイフン。例: my-app）
  出力先ディレクトリ  省略時は ./<app名>
  --template          テンプレート名（現状は default のみ。複数テンプレート対応の予約）
USAGE
}

app_name=""
target=""
template="default"

while [ $# -gt 0 ]; do
  case "$1" in
    --template)
      template="${2:-}"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      if [ -z "$app_name" ]; then
        app_name="$1"
      elif [ -z "$target" ]; then
        target="$1"
      else
        echo "ERROR: 引数が多すぎます: $1" >&2
        usage >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [ -z "$app_name" ]; then
  usage >&2
  exit 1
fi

if [ "$template" != "default" ]; then
  echo "ERROR: 未知のテンプレート: $template（現状は default のみ）" >&2
  exit 1
fi

# アプリ名の検証。生成物の各所（Nix derivation 名 / pyproject name / GCP SA の
# account_id "\${app}-\${env}-run" 等）で使うため、小文字英数字 + ハイフンに限定する。
# GCP service account の account_id は 30 文字以内のため長さも絞る。
if ! printf '%s' "$app_name" | grep -qE '^[a-z][a-z0-9-]{1,19}$'; then
  echo "ERROR: app名は小文字英字始まり・小文字英数字とハイフン・2〜20 文字にしてください: $app_name" >&2
  exit 1
fi
case "$app_name" in
  *"$TEMPLATE_TOKEN"*)
    echo "ERROR: app名に \"$TEMPLATE_TOKEN\" を含めることはできません（置換トークンと衝突します）" >&2
    exit 1
    ;;
esac

target="${target:-./$app_name}"
if [ -e "$target" ] && [ -n "$(ls -A "$target" 2>/dev/null)" ]; then
  echo "ERROR: 出力先が空ではありません: $target" >&2
  exit 1
fi
mkdir -p "$target"

# ── テンプレートのコピー ─────────────────────────────────────────────────────
# flake の self には git 管理外ファイルが含まれないが、作業コピーから直接実行された
# 場合に備えて生成物・キャッシュ類を除外する。
tar -C "$TEMPLATE_ROOT" -cf - \
  --exclude=./.git \
  --exclude=./web/node_modules \
  --exclude=./web/.vite \
  --exclude=./web/reports \
  --exclude=./web/.stryker-tmp \
  --exclude=./web/dist \
  --exclude=./report \
  --exclude=./backend/mutants \
  --exclude=./backend/openapi.json \
  --exclude='./infra/environments/*/.terraform' \
  --exclude='*.db' \
  --exclude='__pycache__' \
  --exclude=./.env \
  . | tar -C "$target" -xf -

# flake 経由の TEMPLATE_ROOT は Nix store（read-only パーミッション）のため、
# 展開後に書き込み権限を戻す
chmod -R u+w "$target"

# ── アプリ名の一括置換（ファイル内容） ───────────────────────────────────────
# -I でバイナリを除外する。置換後に TEMPLATE_TOKEN が残らないことを最後に検証する。
grep -rIl --exclude-dir=.git "$TEMPLATE_TOKEN" "$target" | while IFS= read -r file; do
  sed -i "s/${TEMPLATE_TOKEN}/${app_name}/g" "$file"
done

# ── アプリ名の一括置換（ファイル / ディレクトリ名） ──────────────────────────
# -depth で深い方から処理し、親ディレクトリの rename に壊されないようにする
find "$target" -depth -name "*${TEMPLATE_TOKEN}*" | while IFS= read -r path; do
  base="$(basename "$path")"
  mv "$path" "$(dirname "$path")/${base//${TEMPLATE_TOKEN}/${app_name}}"
done

if grep -rIq --exclude-dir=.git "$TEMPLATE_TOKEN" "$target"; then
  echo "ERROR: 置換漏れがあります:" >&2
  grep -rIl --exclude-dir=.git "$TEMPLATE_TOKEN" "$target" | sed 's/^/  /' >&2
  exit 1
fi

# ── git 初期化 ───────────────────────────────────────────────────────────────
git -C "$target" init -q -b main
git -C "$target" add -A
git -C "$target" -c user.name="${TEMPLATE_TOKEN}-new" -c user.email="noreply@example.com" \
  commit -q -m "init: ${app_name} を ${TEMPLATE_TOKEN} テンプレートから生成"

cat <<DONE

${app_name} を生成しました: $target

次のステップ:
  cd $target
  nix develop        # 開発環境に入る（初回は依存の Nix build が走る）
  make ci            # 全ゲートが green であることを確認

プロダクト固有化のポイント:
  - サンプルドメイン（Note）の置き換え: README「サンプルドメイン」節を参照
  - infra/environments/*/backend.tf の tfstate バケット名と terraform.tfvars.example
  - docs/adr/: ADR-0001（Nix 一元管理）は生成後も有効。以降の判断は自プロジェクトで起票
DONE
