# ADR-0002: テンプレート生成 CLI を Nix flake app として配布する

## ステータス

Accepted

## 関連 ADR

- 関連: ADR-0001（配布経路とツール供給を Nix に一元化する前提を共有）

## コンテキスト

katagami から新プロジェクトを仕立てる手段が GitHub の template repository
（`gh repo create --template`）だけでは不足がある:

- 単純コピーのためパラメータ化できない（アプリ名 "katagami" が flake / pyproject /
  package.json / infra module / lock ファイルに焼き付いたまま生成される）
- 生成後処理（rename・git init・初期コミット）を自動化できない
- 将来、テンプレートを複数保持して使い分ける構想（`--template <name>`）に対応できない

## 決定内容

- 生成 CLI を **Nix flake app** として配布する:
  `nix run github:yusuke0610/katagami#new -- <app名> [出力先] [--template default]`。
  インストール不要で、生成に使うツール（gnused / tar / git 等）は runtimeInputs で固定される
- 生成ロジックの正本は `scripts/new-project.sh`。テンプレートの実体は flake の `self`
  （= git 管理ファイル一式）で、別途テンプレートディレクトリを持たない
- **プレースホルダは埋め込まない**。テンプレート内のアプリ名は必ず `katagami` と書く規約とし、
  生成時にファイル内容・ファイル/ディレクトリ名を一括置換する。lock ファイル内の名前も
  同時に置換されるため、生成直後から lock drift 検証が green になる。置換漏れは生成時に
  自己検証する（残存 grep で fail）
- `--template` は複数テンプレート対応の予約インターフェース。現状は `default`
  （リポジトリルート）のみで、テンプレートが 2 つ目に増えた時点でレイアウト
  （`templates/<name>/` 等）を別 ADR で判断する

## 代替案

- **jinja プレースホルダ方式（cookiecutter / copier）**: テンプレート自体が実行不能になり、
  「テンプレートが常に make ci green」という本リポジトリの中核性質を失う。不採用。
  copier の `copier update`（下流への差分追従）は魅力のため、追従が必要になったら再判断
- **gh repo create --template のまま**: 上記コンテキストの不足を解消できない。
  template repository フラグ自体は残す（閲覧・fork 経路として無害）
- **専用バイナリ（Go / Rust CLI）の配布**: 配布チャネル（brew / releases）の維持コストが
  増える。katagami の利用前提が Nix なので flake app で十分。不採用

## トレードオフ・既知のリスク

- アプリ名の置換はトークン一致ベースのため、`katagami` という文字列を「アプリ名以外の意味」で
  テンプレートに書くことはできない（規約）。生成時の残存 grep と CI のスモーク
  （生成 → 検証）で機械的に守る
- GNU sed 前提（flake app 経由なら Nix が供給。スクリプト直接実行は macOS 標準 sed 非対応）
- 生成物にも本 CLI（flake の apps.new と scripts/new-project.sh）がアプリ名へ rename されて
  引き継がれる。生成先でも「そのリポジトリをテンプレートとして再生成」が自己整合的に動くため
  害はないが、不要なら削除してよい

## 将来の移行条件

- テンプレートが 2 つ以上になった時点で、レイアウト（`templates/<name>/`）と CLI の
  解決ロジックを別 ADR で設計する
- 下流プロジェクトへのテンプレート改善の追従（update 機構）が必要になった場合、
  copier 移行を含めて再判断する

## 関連リンク

- ADR-0001（開発環境と依存を Nix flake で一元管理する）
