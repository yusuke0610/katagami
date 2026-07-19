---
paths:
  - backend/**
  - web/**
---

# コード重複 / DRY ポリシー（共通）

このルールは backend / web すべての領域に適用される。
領域別のコーディング規約（`.claude/rules/{backend,web}/`）と併せて参照すること。

## 原則

### Rule of Three

- **1 回目**: そのまま書く
- **2 回目**: 重複を認識する（まだ抽象化しない）
- **3 回目**: 抽出する。共通化先は下記「抽出先ヒエラルキー」に従う

2 回目で先回り抽象化すると、想定外の差分が出た時に逆に複雑化する。3 つ目の利用箇所が現れた時点で、共通点と差分が明確になっているはずなので、そこで初めて抽出する。

### 過剰な抽象化を避ける

CLAUDE.md にある通り「PEP8 を守るな、PEP8 を理解した上で抽象化しろ」。重複検知 (jscpd) のレポートに引っかかったからといって、機械的に DRY 化してはいけない。「同じ形をしているが意味が違う」コードは別物として残すべき。

判断基準:

- **形は同じだが変更理由が違う** → 抽出しない（偶発的重複）
- **形は違うが変更理由が同じ** → 抽出する（本質的重複）

## 禁止される重複（本質的重複）

以下が複数箇所に書かれていたら、原則として抽出対象とする。

- **ドメインロジック**: スコア計算 / 正規化 / バリデーション / 状態遷移
- **エラーマッピング**: エラーコード ↔ ユーザー向けメッセージの対応表（正本: `errors.py` / `errorMessages.ts`）
- **API パス文字列**: 同じパスのリテラルが複数モジュールに散在
- **環境変数名のリテラル**: `env_keys.py` 以外での文字列参照（`make lint-env-keys` が機械検知）
- **DTO / 型定義**: backend `app/schemas/` ↔ web の手書き型の二重定義（`make codegen-types` の生成型を使う）

## 許容される類似（偶発的重複）

機械検出 (jscpd) で重複として検出されても、抽出してはいけないもの。

- **pytest fixture の最小スキャフォールド**: テスト個別の準備コード
- **Pydantic schema の field 列**: 似た形のレスポンス schema を 1 つにまとめると変更理由が混ざる
- **テストの arrange-act-assert ブロック**: 「同じ流れ」は読みやすさのために残す
- **JSDoc / docstring のテンプレート文言**: セクション見出し等
- **import 文の塊**: 同じライブラリ群を多くのモジュールが import すること自体

## 抽出先ヒエラルキー

重複を抽出すると決めたら、以下の順で配置先を決める。

### Backend (FastAPI)

1. **同一サブパッケージ内の純粋関数** → 同じディレクトリの `_utils.py` か `_helpers.py`
2. **ドメイン横断のロジック** → `backend/app/services/shared/`
3. **HTTP 入出力の変換** → ルーター配下の `_responses.py`
4. **モデル / DTO** → `backend/app/schemas/shared.py`

### Frontend (React + TypeScript)

1. **純粋関数** → `web/src/utils/`
2. **状態を持つ再利用ロジック** → `web/src/hooks/`
3. **汎用 UI** → `web/src/components/ui/`
4. **定数・メッセージ** → `web/src/constants/`

## 検証コマンド

```bash
make dupe-check       # jscpd を実行し report/dupe/ にレポート出力（warn-only）
```

CI の `detect-duplication` ジョブ（warn-only）と `.claude/settings.json` の Stop hook が同じ検査を回す。
