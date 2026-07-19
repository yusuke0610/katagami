---
paths:
  - web/**
---

# Frontend コンポーネント設計ルール

コンポーネント設計の判断基準。行数はあくまで目安（強制閾値ではない）。超過した場合に責務が複数混在していないかを確認するトリガーとして使う。

## 行数の目安

| 対象 | 目安 | 判断 |
|---|---|---|
| コンポーネント（`.tsx`） | 300 行超 | 分割を検討する |
| コンポーネント（`.tsx`） | 500 行超 | 責務が複数混在している可能性が高い。必ず分割する |
| カスタムフック（`.ts`） | 150 行超 | 分割を検討する |

- ページコンポーネント（`pages/`）は薄いラッパーを保つ。ロジックはカスタムフックへ移動する
- 「行数が少ないから問題ない」ではなく「責務が1つに絞られているか」を本質的な判断基準とする

## props drilling の定義と Context 導入の判断基準

**props drilling の定義**: 中間コンポーネントが実際には使わない props を、下位コンポーネントへ「素通し」で渡す構造。

**Context 導入の判断基準**:
- 同じ props を **3 層以上素通し**する場合は Context または専用フックによる解消を検討する
- 2 層までの素通しは許容（過剰な Context 導入を避ける）
- 「素通し」か「実際に使っている」かを区別する。中間コンポーネントが props を使っていれば drilling ではない

**Context を導入すべき条件**:
- drilling が 3 層以上 AND 複数の並列コンポーネントが同じ状態・ハンドラを参照する場合

## モーダル管理パターン

親コンポーネントに `useState` でモーダル開閉状態が 3 個以上になったら専用フックに切り出す。

```tsx
// Bad: 親コンポーネントに複数のモーダル状態が並ぶ
const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
const [showSaveConfirm, setShowSaveConfirm] = useState(false);
const [editingField, setEditingField] = useState<string | null>(null);
```

```tsx
// Good: 専用フックに切り出す（関連度が高いモーダル群は 1 フックにまとめる）
const { deleteConfirm, saveConfirm, openDeleteConfirm /* ... */ } = useFormModals();
```
