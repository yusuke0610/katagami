#!/usr/bin/env bash
# web/package-lock.json を更新する（make lock-web / CI の drift 検証から呼ばれる）。
#
# node_modules は Nix build（importNpmLock）成果物への read-only symlink のため、
# npm install --package-lock-only でも npm が node_modules/.package-lock.json
# （hidden lockfile）を触ろうとして EACCES になる。package.json + package-lock.json
# だけを一時ディレクトリへ写して lock を解決し、結果を書き戻すことで回避する。
set -euo pipefail
cd "$(dirname "$0")/.."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cp web/package.json web/package-lock.json "$tmp/"
(cd "$tmp" && npm install --package-lock-only)
cp "$tmp/package-lock.json" web/package-lock.json
