# ADR 索引

- **本ファイルが ADR の一覧・関係（テーマ・置き換え・関連）の正本**。CONTRIBUTING.md 等に一覧を複製しない。
- ADR を新規作成・ステータス変更したら、同じ PR で本索引を更新する（手順: [CONTRIBUTING.md](../../CONTRIBUTING.md) の「ADR」節）。
- 「全 ADR 一覧」表の **ファイル存在・ステータス・見出し番号は CI で機械検証される**（`scripts/lint-adr-index.sh` / `make lint-adr-index`）。テーマ・関連は人間が編集する（機械検証外）。

## 現在有効な決定（Accepted）

いま生きている判断の早見表。詳細・経緯は各 ADR を参照。

| No. | タイトル | テーマ | 一言サマリ |
|---|---|---|---|
| [ADR-0001](./0001-nix-managed-toolchain.md) | 開発環境と依存を Nix flake で一元管理する（uv2nix + importNpmLock） | 開発プロセス / 品質 | toolchain・Python 依存・node_modules を lock 正本の Nix build に統一し、ローカル / CI の drift を排除 |

## 全 ADR 一覧

ステータスの定義と変更手順は [CONTRIBUTING.md](../../CONTRIBUTING.md) を参照。

| No. | タイトル | ステータス | テーマ | 置き換え・関連 |
|---|---|---|---|---|
| [ADR-0001](./0001-nix-managed-toolchain.md) | 開発環境と依存を Nix flake で一元管理する（uv2nix + importNpmLock） | Accepted | 開発プロセス / 品質 | — |
