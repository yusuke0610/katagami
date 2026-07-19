#!/usr/bin/env bash
# web/package-lock.json を更新する（make lock-web / CI の drift 検証から呼ばれる）。
#
# node_modules は Nix build（importNpmLock）成果物への read-only symlink のため、
# npm install --package-lock-only でも npm が node_modules/.package-lock.json
# （hidden lockfile）を触ろうとして EACCES になる。package.json + package-lock.json
# だけを一時ディレクトリへ写して lock を解決し、結果を書き戻すことで回避する。
#
# 鶏卵問題（package.json に依存を追加した直後）:
#   lock が未更新だと importNpmLock の評価が失敗し devshell 自体が建たないため、
#   `make lock-web`（devshell 経由）が使えない。その場合は flake に依存しない
#   `nix shell nixpkgs#nodejs_22 --command bash scripts/npm-lock.sh` で lock を
#   ブートストラップ更新し、devshell が建つようになってから `make lock-web` で
#   正規化（devshell の npm による整形）を一度通すこと。
set -euo pipefail
cd "$(dirname "$0")/.."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cp web/package.json web/package-lock.json "$tmp/"
(cd "$tmp" && npm install --package-lock-only)
cp "$tmp/package-lock.json" web/package-lock.json
