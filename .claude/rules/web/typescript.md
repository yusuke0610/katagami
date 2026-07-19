---
paths:
  - web/**
---

# TypeScript/React コーディング規約

- ESLint / Prettier の設定に従うこと
- リントは `make lint-web`、テストは `make test-web` を使う（Nix devshell 経由で解決される）
- 個別スクリプトを叩きたい場合は `nix develop --command bash -c "cd web && npm run <script>"` を使う。生シェルでの `cd web && npm ...` は AI エージェントでは禁止

## node_modules は Nix 管理（重要）

- `web/node_modules` は importNpmLock（Nix build）成果物への **read-only symlink**。`npm install` / `npm ci` は禁止（EACCES で失敗するか、Nix 管理を壊す）
- 依存を変更するときは `web/package.json` を編集 → `make lock-web` で `package-lock.json` を更新 → devshell 再突入（`nix develop`）で新しい node_modules が link される
- `node_modules` 内へ書き込むツール設定は使えない。キャッシュ類はプロジェクト側ディレクトリへ逃がす（例: vite の `cacheDir: ".vite"`）
