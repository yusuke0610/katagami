---
paths:
  - web/**
---

# Frontend テスト方針

## いつテストを書く・回すか（トリガー）

### ユニット / コンポーネントテスト（vitest）

- **新規フック追加**: 必ず `*.test.ts` を作成（loading / success / error の 3 パス最低限）
- **既存フックの契約変更**: 戻り値・副作用が変わる場合、既存 `*.test.ts` の assert を見直す
- **API クライアント層の変更**: 対応する `*.test.ts` を更新（エラーハンドリングの挙動）
- **コンポーネント追加**: ロジックを含むものはテストを追加。表示のみのものは省略可

## 実行コマンド

```bash
make test-web                                              # vitest（unit / コンポーネント）
```

特定の vitest スイートだけ回す場合:
```bash
nix develop --command bash -c "cd web && npx vitest run src/App.test.tsx"
```

## OK 基準（達成条件）

以下をすべて満たして初めて「テスト OK」と判定する:

1. **全 vitest pass**: `make test-web` が exit 0
2. **lint が pass**: `make lint-web` も同時に通ること
3. **build が通る**: `make build-web`（tsc + vite build）が通ること。TypeScript の型エラーが残っていないこと
4. **新規・変更コードに対応するテストが存在する**:
   - 新規フック → 主要分岐ごとに 1 ケース（最低 3 ケース）
   - 新規 API モジュール → 成功 / 4xx / 5xx の 3 パス

## アンチパターン

- `await new Promise(r => setTimeout(r, ms))` での同期待ち（フレーキー）
- `data-testid` 過剰依存（ユーザー視点のセレクタを優先: role / name / placeholder）
- snapshot testing で大きな DOM 全体をスナップショットする（差分の意味が不明瞭になる）
