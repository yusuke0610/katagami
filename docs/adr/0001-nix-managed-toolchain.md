# ADR-0001: 開発環境と依存を Nix flake で一元管理する（uv2nix + importNpmLock）

## ステータス

Accepted

## 関連 ADR

なし

## コンテキスト

katagami は「SaaS 開発の規律を機械検証で守る縦串テンプレート」であり、規律の前提として
**ローカルと CI のビルド経路が一致していること**（drift の排除）と、
**依存の供給網リスクが lock で固定されていること**が必要になる。

従来型の構成（ホストの Python + venv、ホストの Node + `npm install`）には次の問題がある:

- 開発者ごと・CI ランナーごとにツールチェーンのバージョンが揺れる
- venv / node_modules がロックと乖離した状態で作業が進み得る（`pip install` / `npm install` の手動操作）
- セットアップ手順が README の散文になり、機械検証できない

## 決定内容

開発環境の SSoT を `flake.nix` に一本化し、言語別の依存も lock ファイルを正として Nix build で構成する。

| 領域 | 正本 | Nix 化の仕組み | 禁止事項 |
|---|---|---|---|
| ツールチェーン（python / node / uv / gh 等） | `flake.nix` | devshell（`nix develop`） | ホスト直のツール実行 |
| backend Python 依存 | `backend/pyproject.toml` + `uv.lock`（全依存 `==` 固定） | uv2nix の `mkVirtualEnv`（wheel 優先） | `.venv` / `uv sync` |
| web Node 依存 | `web/package.json` + `package-lock.json` | `importNpmLock.buildNodeModules`。devshell 突入時に `web/node_modules` へ symlink | `npm install` / `npm ci` |

- lock の更新だけは各エコシステムのネイティブツールで行う（`uv lock` / `make lock-web`）。
  uv / npm は「lock 更新専用」であり依存の導入には使わない。
- CI もすべて Nix devshell 経由で Makefile のターゲットを実行し、ローカルと同一経路にする。
- lock と正本の drift は CI が検証する（`uv lock --check` / `scripts/npm-lock.sh` + `git diff --exit-code`）。

## 代替案

- **ホスト toolchain + venv + npm ci**: セットアップは軽いが、バージョン揺れと手動操作による drift を機械的に防げない。不採用。
- **devcontainer / Docker 開発環境**: 環境は固定できるが、macOS でのファイル I/O 性能と、コンテナ外ツール（エディタ・AI エージェント）との統合コストが高い。Nix devshell はホストプロセスのまま環境だけ固定できる。不採用。
- **node_modules は npm ci のまま（Nix 化しない）**: 導入は容易だが、Python 側だけ Nix build という非対称が残り、npm ci の実行タイミング次第で lock と node_modules が乖離し得る。テンプレートとしては一貫させる価値が大きいため不採用。

## トレードオフ・既知のリスク

- Nix（flakes / uv2nix / importNpmLock）の学習コストがかかる。
- `web/node_modules` は read-only の Nix store への symlink であるため:
  - node_modules 内へ書き込むツールは使えない（vite のキャッシュは `web/.vite` へ逃がしている）
  - `npm install --package-lock-only` ですら hidden lockfile（`node_modules/.package-lock.json`）に触れて失敗するため、lock 更新は一時ディレクトリ経由（`scripts/npm-lock.sh`）で行う
- sdist ビルドが必要な Python パッケージが増えると、wheel 優先方針に個別 override が必要になる。

## 将来の移行条件

- importNpmLock が postinstall スクリプト必須の依存で破綻した場合、その依存に限り buildNodeModules の設定で対応し、解決不能なら web のみ npm ci 方式へ戻すことを別 ADR で判断する。
- チーム規模や CI 時間の制約で Nix build のコストが問題化した場合も、別 ADR で見直す。

## 関連リンク

- PR #1（骨格: flake.nix + Makefile + CI + 空アプリ）
