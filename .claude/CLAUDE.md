# katagami - Claude Code ガイドライン

## このファイルの読み方

- 本ファイルは全体ルールの索引。AI エージェント（Claude Code 含む）が最初に読むべき内容を集約している。
- 領域固有ルール（backend / web）は `.claude/rules/<scope>/*.md` に分割済み。対象パスを編集する際に自動でロードされる。重複は避け、詳細は各 rule ファイルへ寄せる。
- **決定論的ロジック層（mutmut / stryker のミューテーション対象）を変更する場合は TDD（red→green→refactor）が必須。** 手順の正本は `.claude/rules/common/tdd.md`。テスト差分の随伴は `make lint-tdd`（`make ci` に含まれる）が機械検証する。

## AI エージェント実行方法

**原則: 開発ツールはすべて Nix devshell 経由で実行する。** ホスト側に Python / Node / ruff が入っていない前提。

### 第一選択: `make` ターゲット

Makefile は `nix develop --command bash -c "..."` でラップ済み。AI は基本これを使う。**最新の一覧と詳細は `make help`** で確認する（本表は AI が即時参照する代表的なターゲットのみ）。

| 用途 | コマンド |
|---|---|
| CI 相当一括 | `make ci` （= `lint + format-check + test + build-web`） |
| Backend lint | `make lint-backend` |
| Backend 型チェック | `make typecheck-backend` （pyright。`make lint` に含まれる） |
| Backend test | `make test-backend` |
| Frontend lint | `make lint-web` |
| Frontend test | `make test-web` |
| Lint 自動修正 | `make lint-fix` |
| env 名 drift 検知 | `make lint-env-keys` （`make lint` に含まれる） |
| ADR 索引 drift 検知 | `make lint-adr-index` （`make lint` に含まれる） |
| TDD 随伴検知 | `make lint-tdd` （`make lint` に含まれる） |
| web 依存 lock 更新 | `make lock-web` （package.json 変更後に必須） |
| マイグレーション | `make migrate` / `make migrate-create MSG="..."` |
| コード重複検知 | `make dupe-check` （結果: `report/dupe/`。warn-only） |
| ミューテーションテスト | `make mutation-backend` / `make mutation-web` （**長時間**。週次 CI で実行） |

### 第二選択: `nix develop --command` ラッパー

make に無い操作（特定ファイルだけ ruff したい等）の場合のみ使う:

```bash
nix develop --command bash -c "cd backend && ruff check app/main.py"
nix develop --command bash -c "cd backend && python -m pytest tests/test_health.py -q"
nix develop --command bash -c "cd web && npx vitest run src/App.test.tsx"
```

python / pytest / ruff は devshell の Nix build 環境（`katagami-backend-env`）から、node / npm と `web/node_modules` は importNpmLock の Nix build から PATH 解決される（`.venv` / `npm install` は存在しない）。

### 禁止: 生シェルでの直接実行

`cd backend && python -m pytest ...` を nix の外で叩くと、backend の Python 環境（uv2nix build）自体が PATH に無い。web も同様に `node_modules` が Nix 成果物への symlink であることを前提とする。AI は nix wrap を必ず通す。

### 禁止: `npm install` / `uv sync`

依存の実体はすべて Nix build が提供する。依存を変更するときは正本（`backend/pyproject.toml` / `web/package.json`）を編集し、lock を再生成する（下記「SSoT 生成物」）。`npm install` は `web/node_modules`（read-only symlink）を壊そうとして失敗する。

### Sandbox と nix の競合（重要）

Claude Code の sandbox は `~/.cache/nix/fetcher-locks/*.lock` への書き込みを拒否することがある。`make lint-backend` 等が `error: opening lock file ...: Operation not permitted` で落ちる場合は sandbox を無効化して再実行する（Bash ツールの `dangerouslyDisableSandbox: true`）。nix の lock 書き込みは安全な操作なので例外として許容してよい。

## コーディング規約（共通）

- **コメント・ドキュメント**: コード内コメント・docstring・JSDoc はすべて**日本語**で記述する。
- **エラーメッセージ**: HTTPException の `detail` 等、ユーザーに返すメッセージはすべて**日本語**。
- **エラー契約**: API エラーは必ず `AppErrorResponse` の共通形（`code` / `message` / `action` / `error_id`）で返す。backend は `raise_app_error()`（`app/core/errors.py`）を使い、素の文字列 detail を増やさない。エラーコードの集合は FE（`web/src/constants/errorCodes.ts`）と `make lint-env-keys` で同期される。追加手順は `errors.py:ErrorCode` の docstring を参照。
- **例外の握りつぶし禁止**: `except SomeException: pass` は禁止。最低でも `logger.debug/warning/error` でログを残す。補助処理で抑制する場合も `logger.warning` でログを出すこと。
- **過剰な抽象化を避ける**: PEP8 を守るな、PEP8 を理解した上で抽象化しろ。

言語別の詳細ルールは `.claude/rules/{backend,web}/` を参照。

## CI 確認ルール

アプリケーションの改修後は、ローカルで CI 相当を pass させてから完了報告する。

```bash
# 一括（最速・推奨）
make ci
```

### SSoT 生成物のトリガー — 必須

**SSoT（正本）から自動生成される成果物に影響する変更をしたら、生成物の再生成とコミットは必須。** 正本だけ直して生成物を更新し忘れると、CI の drift チェックで必ず落ちる。

| 正本（変更したら） | 再生成コマンド | コミットすべき生成物 | CI の drift 検証 |
|---|---|---|---|
| backend の OpenAPI スキーマ（`app/schemas/` の Pydantic、ルーターのシグネチャ・query/path パラメータ・**endpoint/schema の docstring**） | `make codegen-types` | `web/src/api/generated.ts`（`backend/openapi.json` は gitignore で対象外） | `codegen-drift` |
| `backend/pyproject.toml` の `[project.dependencies]` | `nix develop --command bash -c "cd backend && uv lock"` | `backend/uv.lock` | `test-backend` の `uv lock --check` |
| `web/package.json` の dependencies | `make lock-web` | `web/package-lock.json` | `test-web` の drift 検証（scripts/npm-lock.sh） |

- **判定基準**: 「OpenAPI スペックに出るものを変えたか」。エンドポイントの追加・削除、リクエスト/レスポンス型の変更はもちろん、**docstring の文言変更だけでも description として spec に反映される**ため再生成が要る。
- backend の `app/schemas/` / ルーターを触ったら、`make ci` 前に `make codegen-types` を回して `git diff web/src/api/generated.ts` を確認する。差分が出たら必ず同じ PR でコミットする。

新しい SSoT→生成物の系統を追加した場合は、本表に行を足して再発防止の対象に含める。

CI 定義: `.github/workflows/ci.yml`

## 作業開始時のブランチ運用（デフォルト）

**新しい作業に着手するときは、最初に main から作業ブランチを切る。** これはデフォルト挙動であり、合言葉や明示指示を待たない。

- 作業開始時に `main` ブランチ上にいる場合、コードに触れる前に `git fetch origin main` してから `origin/main` 起点で feature ブランチを切る（例: `git switch -c feat/<topic> origin/main`）。
- 既に feature ブランチ上にいる場合:
  - 差分（未コミット変更 or main より進んだコミット）が**無い**ならそのまま継続してよい。
  - 差分が**ある**場合は、別作業の続きと混ざる恐れがあるため**勝手に切り直さず、main から新しく作業ブランチを切るべきかユーザーに相談する**。
- ブランチ名は変更内容が分かる英語の kebab-case（`feat/` `fix/` `docs/` `refactor/` 等のプレフィックス）。
- 例外: 単発の調査・閲覧のみでコミットを伴わない作業は、ブランチを切らなくてよい。

## コミット / PR フロー

修正〜PR は **合言葉ベースの段階制御**で進める。各段で必ず止まる。diff 全文は会話に出さず（ユーザーがエディタで確認する）、要約と判断が必要な事案だけ提示する。

| 合言葉 | やること |
|---|---|
| **stage** | 実装 → `make ci` → `git add` まで。会話に「サマリ＋判断が必要な事案」を提示し、ユーザーのエディタ確認を待つ |
| **commit** | コミットメッセージ案（**日本語**）を提示 → **ユーザー承認を待ってから** commit。承認は必須ゲート |
| **pr** | `git fetch origin main` → `git log --oneline origin/main..HEAD` で最新 main との差分を確認 → `git push` → `gh pr create`（**日本語**タイトル/本文、base = `main`）→ PR URL を返す |
| **pr 後の追従** | `gh pr checks` / `gh pr view --comments` で CI と指摘を確認。こけ・指摘があれば修正 → `make ci` → 同ブランチへ push を green かつ解消まで繰り返す。**ただし意思決定を要する指摘（設計・API/型契約・挙動変更）と diff 範囲を逸脱する指摘は、勝手に直さず対応案を提示して承認を待つ** |

修正依頼時に「PR まで」等と言われたら、コミットメッセージ承認だけ挟んで一気通貫で進めてよい。段階を飛ばす指定も尊重する。

**stage 時に必ず明示する「判断が必要な事案」**（無ければ `git diff --stat` だけで軽く流す）:

- **破壊的変更**: ファイル削除 / 既存挙動の変更 / API・型の契約変更
- **設計分岐**: 実装方針が複数あって AI が選んだ箇所
- **依頼範囲外**: 直すために範囲外を触る必要が出た
- **CI 注意点**: 落ちた・skip した・新規テスト追加が必要な変更
- **依存 / 環境変数の追加**: 新パッケージ、env var 追加
- **大量自動生成差分**: lockfile など、レビュー対象外として切り分けたいもの
- **未完 / TODO**: 一部を後回しにした場合

## 環境変数

**正本**:
- 環境変数名の定数定義: `backend/app/core/env_keys.py`
- ローカル開発のテンプレート: `.env.example`

backend 内で `os.getenv("XXX")` のように文字列リテラル直接参照は禁止。`from app.core import env_keys` した上で `os.getenv(env_keys.XXX)` を使う。新規環境変数を追加するときは env_keys.py の docstring に記載の手順（`.env.example` 等への同期）を必ず実行する。drift は `make lint-env-keys`（CI 含む）が機械検証する。

## ADR（Architecture Decision Record）

技術選定・アーキテクチャ判断を行う際は必ず ADR 索引（`docs/adr/README.md`）から関連 ADR を辿り、既存の判断と矛盾しない実装を行うこと。

新たに重要な技術判断を行う場合は `CONTRIBUTING.md` の ADR 運用ルールに従い、ADR を作成してから実装を開始する。**ADR の新規作成・ステータス変更をしたら、同じ PR で索引も更新する**（存在・ステータス・見出し番号の整合は `make lint-adr-index` が CI で検証する）。

- ADR 索引（一覧・テーマ・決定系統の正本）: `docs/adr/README.md`
- テンプレート: `docs/adr/0000-template.md`
- 運用ルール: `CONTRIBUTING.md`

## モデル切り替えルール（コスト最適化）

git 定型作業は Haiku で十分なため、適切なタイミングでユーザーにモデル切り替えを案内する。
Claude Code は `/model` コマンドを自分では実行できないため、案内を出してユーザーに切り替えてもらう。

| 作業フェーズ | 推奨モデル |
|---|---|
| コード修正・実装・調査・CI 修正 | セッション開始時の設定モデル |
| `make ci` pass 後の git 操作（add / commit / push / pr） | Haiku |

**制約**:
- CI が落ちた場合の修正（実装フェーズ）は Haiku のまま行わない。修正は元のモデルで行い、再度 `make ci` を通してから Haiku に切り替える
