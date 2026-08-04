#!/usr/bin/env bash
# 生成プロジェクトからテンプレート固有物とサンプルドメインを除去する（ADR-0003）。
#
# scripts/new-project.sh から、テンプレートのコピー直後・アプリ名置換前に呼ばれる。
# 除去対象は 3 系統:
#   (1) テンプレート配布機構（生成 CLI / ADR-0002,0003 / template-smoke ジョブ）
#   (2) katagami 自身の自己紹介・作成経緯（README / ADR-0001 の文言）
#   (3) サンプルドメイン Note 一式とその配線
#
# 設計上の約束: 全操作は「アンカーが見つからなければ即 fail」する。テンプレート側の
# 構造が変わってアンカーが陳腐化した場合、生成が黙って劣化するのではなく生成時点で
# 落ちる。加えて CI の template-smoke が生成物で make ci + codegen 差分を検証する。
set -euo pipefail

target="${1:?使い方: strip-template-meta.sh <生成先ディレクトリ>}"

die() {
  echo "ERROR: strip-template-meta: $*" >&2
  exit 1
}

# ── 編集ヘルパ ───────────────────────────────────────────────────────────────

# 正規表現に一致する行を削除する（1 行も一致しなければ fail）
drop_lines() {
  local file="$1" pattern="$2" path="$target/$1"
  [ -f "$path" ] || die "$file が存在しません"
  grep -qE "$pattern" "$path" || die "$file: アンカー /$pattern/ が見つかりません"
  grep -vE "$pattern" "$path" >"$path.strip.tmp"
  mv "$path.strip.tmp" "$path"
}

# start_re の行から end_re の行までを削除する。
# mode=exclusive のとき end_re の行は残す（次ブロックの先頭を終端に使う場合）。
drop_range() {
  local file="$1" start_re="$2" end_re="$3" mode="${4:-inclusive}" path="$target/$1"
  [ -f "$path" ] || die "$file が存在しません"
  awk -v s="$start_re" -v e="$end_re" -v mode="$mode" '
    state == 0 {
      if ($0 ~ s) { state = 1; hit = 1; next }
      print; next
    }
    {
      if ($0 ~ e) {
        state = 0
        if (mode == "exclusive") print
      }
      next
    }
    END { if (!hit) exit 3 }
  ' "$path" >"$path.strip.tmp" || die "$file: 範囲アンカー /$start_re/ が見つかりません"
  mv "$path.strip.tmp" "$path"
}

# sed 置換を適用し、置換前パターンが残っていないことを検証する
substitute() {
  local file="$1" expr="$2" gone_re="$3" path="$target/$1"
  [ -f "$path" ] || die "$file が存在しません"
  grep -qE "$gone_re" "$path" || die "$file: 置換アンカー /$gone_re/ が見つかりません"
  sed -i "$expr" "$path"
  ! grep -qE "$gone_re" "$path" || die "$file: 置換後もパターン /$gone_re/ が残っています"
}

# 連続する空行を 1 行に潰す（ブロック削除跡の空行を残さない）
collapse_blank_runs() {
  local path="$target/$1"
  [ -f "$path" ] || die "$1 が存在しません"
  cat -s "$path" >"$path.strip.tmp"
  mv "$path.strip.tmp" "$path"
}

remove_path() {
  local path="$target/$1"
  [ -e "$path" ] || die "$1 が存在しません"
  rm -rf "$path"
}

# ── (3) サンプルドメイン Note 一式 ───────────────────────────────────────────

remove_path backend/app/models/note.py
remove_path backend/app/schemas/note.py
remove_path backend/app/routers/notes.py
remove_path backend/app/services/notes
remove_path backend/app/services/tasks/handlers/note_summarize.py
remove_path backend/tests/test_notes.py
remove_path backend/tests/test_summarizer.py
remove_path backend/alembic_migrations/versions/20260719_0003_add_notes_table.py
remove_path web/src/api/notes.ts
remove_path web/src/api/notes.test.ts

# 配線の除去。モデル登録・ルーター登録・ハンドラ登録・ミューテーション対象の 4 箇所
drop_lines backend/app/models/__init__.py '^from app\.models\.note import Note$'
substitute backend/app/models/__init__.py \
  's/^__all__ = \["AsyncTask", "Note"\]$/__all__ = ["AsyncTask"]/' \
  '^__all__ = \["AsyncTask", "Note"\]$'
substitute backend/app/main.py \
  's/^from app\.routers import notes, tasks$/from app.routers import tasks/' \
  '^from app\.routers import notes, tasks$'
drop_lines backend/app/main.py '^app\.include_router\(notes\.router\)$'
drop_lines backend/app/services/tasks/handlers/__init__.py \
  '^from app\.services\.tasks\.handlers import note_summarize'
drop_lines backend/pyproject.toml '^    "app/services/notes/summarizer\.py",'

# 生成型（openapi-typescript 出力）から Note 由来のエントリを落とす。
# 正しさは template-smoke の codegen 差分検証（実際の再生成との一致）が担保する。
generated="$target/web/src/api/generated.ts"
[ -f "$generated" ] || die "web/src/api/generated.ts が存在しません"
awk '
  function is_target(line) {
    return (line ~ /^    "\/api\/notes/) ||
           (line ~ /^        (NoteCreate|NoteResponse|NoteUpdate|TaskAccepted): \{$/) ||
           (line ~ /^    [a-z_]+_api_notes[a-z_]*: \{$/)
  }
  # 削除中はネストしたコメントも含めて読み飛ばす（コメント判定より先に評価する）
  skip {
    if ($0 == closer) skip = 0
    next
  }
  # doc コメントは直後のキーを見るまで出力を保留する（削除時はコメントごと落とす）
  /^[ \t]*\/\*\*/ { incmt = 1 }
  incmt {
    buf[nbuf++] = $0
    if ($0 ~ /\*\//) incmt = 0
    next
  }
  {
    if (is_target($0)) {
      nbuf = 0
      skip = 1
      hit = 1
      match($0, /^ +/)
      closer = substr($0, 1, RLENGTH) "};"
      next
    }
    for (i = 0; i < nbuf; i++) print buf[i]
    nbuf = 0
    print
  }
  END {
    for (i = 0; i < nbuf; i++) print buf[i]
    if (!hit) exit 3
  }
' "$generated" >"$generated.strip.tmp" || die "generated.ts: Note 由来のエントリが見つかりません"
mv "$generated.strip.tmp" "$generated"
! grep -q "Note" "$generated" || die "generated.ts に Note 由来の記述が残っています"

# ── (1) テンプレート配布機構 ─────────────────────────────────────────────────

remove_path docs/adr/0002-template-generator-cli.md
remove_path docs/adr/0003-strip-template-meta-on-generate.md
drop_lines docs/adr/README.md '^\| \[ADR-000[23]\]'

drop_range flake.nix '^        # --- テンプレート生成 CLI' '^        [}];$'
drop_lines flake.nix '^          new-project = newProject;$'
drop_range flake.nix '^        apps[.]new = [{]$' '^        [}];$'
collapse_blank_runs flake.nix
drop_range .github/workflows/ci.yml \
  '^  # テンプレート生成のスモーク' '^  # コード重複検知' exclusive

substitute scripts/lint-tdd.sh \
  's|テンプレート生成直後（nix run \.#new）など origin 未設定のリポジトリでは|origin 未設定のリポジトリ（生成直後・ローカル専用リポジトリ等）では|' \
  'テンプレート生成直後（nix run \.#new）'
substitute scripts/lint-tdd.sh \
  's|remote origin 未設定。テンプレート生成直後のリポジトリ等|remote origin 未設定|' \
  'テンプレート生成直後のリポジトリ等'

# 生成 CLI 本体と本スクリプト自身を最後に落とす
remove_path scripts/new-project.sh
remove_path scripts/strip-template-meta.sh

# ── (2) 自己紹介・作成経緯 ───────────────────────────────────────────────────

# ADR-0001 は決定内容（Nix 一元管理）が生成後も有効なため残し、katagami 固有の
# 文脈（テンプレートとしての自己言及・元リポジトリの PR 番号）だけを差し替える
substitute docs/adr/0001-nix-managed-toolchain.md \
  's|^katagami は「SaaS 開発の規律を機械検証で守る縦串テンプレート」であり、規律の前提として$|本プロジェクトは開発規律を機械検証で守ることを前提とする。その前提として|' \
  '^katagami は「SaaS 開発の規律を機械検証で守る縦串テンプレート」であり'
substitute docs/adr/0001-nix-managed-toolchain.md \
  's|テンプレートとしては一貫させる価値が大きいため不採用。|構成を一貫させる価値が大きいため不採用。|' \
  'テンプレートとしては一貫させる価値が大きいため不採用。'
substitute docs/adr/0001-nix-managed-toolchain.md \
  's|^- PR #1（骨格: flake\.nix + Makefile + CI + 空アプリ）$|- なし|' \
  '^- PR #1（骨格'

# README はテンプレートのカタログ（縦串一覧・生成手順・サンプルドメイン解説）が
# 主内容のため、プロダクト向けの最小構成へ差し替える。
# 本文中の katagami は呼び出し元の一括置換でアプリ名になる
cat >"$target/README.md" <<'README'
# katagami

## 開発

前提: [Nix](https://nixos.org/download/)（flakes 有効）。ホストに Python / Node を入れる必要はない。

```bash
nix develop        # 開発環境に入る（初回は依存の Nix build が走る）
make setup         # 初回セットアップ
make ci            # lint + format-check + test + build を一括実行（CI 相当）

make dev-backend   # API 起動（localhost:8000）
make dev-web       # Vite 起動（localhost:5173）
```

タスクの一覧は `make help` を参照。

## 構成

| パス | 内容 |
| --- | --- |
| `flake.nix` | 開発環境の SSoT。backend Python 依存は uv2nix、web node_modules は importNpmLock で Nix build（`.venv` / `npm install` 不要） |
| `backend/` | FastAPI アプリ。依存の正本は `pyproject.toml` + `uv.lock`（全依存 `==` 固定） |
| `web/` | React + Vite + TypeScript アプリ。依存の正本は `package.json` + `package-lock.json`（更新は `make lock-web`） |
| `infra/` | OpenTofu（stack module + dev/stg/prod） |
| `docs/adr/` | ADR（テンプレート + 索引） |
| `Makefile` | タスクランナー |
| `.github/workflows/` | CI（lint + typecheck + test + build + codegen/lock drift + jscpd + OpenTofu + 週次 mutation） |

## 開発規律（機械検証される約束）

| 規律 | 内容 | 正本 | 検証 |
| --- | --- | --- | --- |
| 環境変数 | 名前の SSoT。リテラル参照禁止・`.env.example` / cloud_run と突合 | `backend/app/core/env_keys.py` | `make lint-env-keys` |
| エラー契約 | 全 API エラーを `AppErrorResponse` 形へ正規化。コード集合を BE↔FE で同期 | `backend/app/core/errors.py` | `make lint-env-keys` |
| 型契約 | Pydantic schema → `web/src/api/generated.ts` を機械生成 | `backend/app/schemas/` | CI `codegen-drift` |
| DB | スキーマ正本はマイグレーション。`DATABASE_URL` でパラメータ化 | `backend/alembic_migrations/` | `make migrate` + 適用テスト |
| 非同期タスク | 状態遷移（pending→processing→completed/retrying/dead_letter）+ ハンドラレジストリ | `backend/app/services/tasks/` | 状態遷移テスト |
| 品質ゲート | DRY 検知（jscpd）/ ミューテーション（mutmut / Stryker）/ TDD 随伴 lint | `.jscpd.json` / `[tool.mutmut]` / `stryker.conf.json` | `make dupe-check` / 週次 CI / `make lint-tdd` |
| ADR | 意思決定の記録。索引 ↔ ファイルの drift を機械検証 | `docs/adr/README.md` | `make lint-adr-index` |
| AI 協働 | 実行方法（Nix 経由必須）・コミット / PR フロー・scoped rules | `.claude/CLAUDE.md` + `.claude/rules/` | —（運用） |

開発の進め方は [CONTRIBUTING.md](CONTRIBUTING.md) を参照。
README

echo "strip-template-meta: テンプレート固有物とサンプルドメインを除去しました"
