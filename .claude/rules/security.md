---
paths:
  - backend/**
  - web/**
---

# セキュリティルール（全領域横断）

このファイルは backend / web すべての領域に適用される横断セキュリティルール。

---

## 秘密情報管理（Secrets Management）

### Git に含めてはいけないもの

- `.env` / `.env.*` — ローカル開発用環境変数
- `*.pem` / `*.key` — 秘密鍵・証明書
- クラウドのサービスアカウント鍵・認証トークンをハードコードした設定ファイル

### ログへの秘密情報出力禁止

認証トークン・API キー・パスワード・個人情報（メールアドレス含む）をログに出力しない。
デバッグ目的でも `logger.debug` にこれらを含めないこと。

---

## 入力バリデーション・出力エスケープ

### Backend

- **Pydantic バリデーション必須**: API エンドポイントへの入力はすべて `app/schemas/` の Pydantic モデルで型・制約を検証する。`Any` 型や `dict` 型の素通しは避ける
- **SQL インジェクション防止**: DB アクセスは ORM / Core のパラメータバインドを使う。文字列連結でクエリを組み立てることは禁止

### Frontend

- **`dangerouslySetInnerHTML` は原則禁止**: 外部コンテンツや動的文字列を `innerHTML` / `dangerouslySetInnerHTML` に渡さない。React の自動エスケープを信頼する
- **外部リンク**: `<a target="_blank">` には必ず `rel="noopener noreferrer"` を付ける（タブナビゲーション攻撃の防止）
- **URL パラメータの扱い**: `window.location.search` 等から取得した値を DOM に直接レンダリングしない。必ず React の `state` / `props` 経由で扱う

---

## Frontend セキュリティ

### トークン管理

- 認証を導入する場合、トークンは `HttpOnly` + `Secure` Cookie で管理する
- `localStorage` / `sessionStorage` にトークンを保存しない（XSS で盗取されるリスク）
- グローバル state（store）にも生のトークン文字列を乗せない

### XSS 対策まとめ

1. `dangerouslySetInnerHTML` 禁止（上述）
2. Markdown レンダラー等を使う場合は sanitize オプションを有効化する
3. `eval()` / `Function()` コンストラクタの使用禁止

### 依存関係

- `npm audit` で High / Critical CVE が検出された場合は PR マージ前に対処する
- `--force` で無視せず脆弱なパッケージを更新すること

---

## Backend セキュリティ（追加事項）

### ファイルアップロード

ファイルアップロード機能を追加する場合は以下をすべて実装する:

1. **MIME タイプ検証**: `Content-Type` ヘッダだけでなくファイルのバイト列（magic bytes）で検証する
2. **ファイルサイズ上限**: エンドポイント側で上限を設け、OOM を防ぐ
3. **ファイル名サニタイズ**: パストラバーサル（`../` 等）を除去する。UUIDv4 でリネームするのが最もシンプル
4. **保存先**: 本番ではローカルファイルシステムに保存せず外部ストレージを使う

### 依存関係

- 依存はすべて `==` で固定する（`backend/pyproject.toml` 冒頭コメント参照）
- CVE 検出時はレンジ更新ではなく明示的にバージョンを引き上げる

---

## セキュリティレビューチェックリスト

AI エージェントがコードを変更した後に確認する項目:

- [ ] 秘密情報（トークン・キー・パスワード）が Git に含まれていないか
- [ ] 入力バリデーションが境界（API エンドポイント・フォーム）で行われているか
- [ ] `dangerouslySetInnerHTML` / `innerHTML` の新規使用がないか
- [ ] ログに個人情報・認証情報が出力されないか
- [ ] `target="_blank"` に `rel="noopener noreferrer"` が付いているか
