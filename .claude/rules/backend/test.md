---
paths:
  - backend/**
---

# Backend テスト方針

## いつテストを書く・回すか（トリガー）

以下のいずれかに該当する変更を行った場合、テスト追加・更新と実行が必須:

- **新規エンドポイント追加**: 必ず統合テスト（`tests/test_<router>.py`）を追加し、正常系・バリデーションエラー・404 を最低限カバーする（認可がある場合は認可エラーも）
- **既存エンドポイントの契約変更**: ステータスコード / レスポンス body / 副作用が変わる場合、既存テストの assert を見直す（旧契約を固定化したテストが残ると意図が後退する）
- **サービス層のロジック変更**: 該当ユニットテスト（`tests/test_<module>.py`）を更新

## 実行コマンド

```bash
make test-backend                    # 全テスト
```

特定ファイルだけ回す場合:
```bash
nix develop --command bash -c "cd backend && python -m pytest tests/test_health.py -q"
```

## OK 基準（達成条件）

以下をすべて満たして初めて「テスト OK」と判定する:

1. **全テスト pass**: `make test-backend` が exit 0
2. **新規・変更コードに対応するテストが存在する**:
   - 新規エンドポイント → ハッピーパス + 不正入力（+ 認可失敗、認可がある場合）
   - 新規サービス関数 → 主要分岐ごとに 1 ケース
3. **失敗パスを明示的に検証している**: 例外を `pytest.raises(ExpectedError)` で必ず assert する。silent return を許容するテストは書かない
4. **モックは最小限**: DB はモックしない（実 DB のテスト用セッションを使う）。外部サービス（外部 API 等）はモックする
5. **lint が pass**: `make lint-backend` も同時に通ること

## アンチパターン

- `assert result is not None` だけで満足する（中身を検証していない）
- `try / except Exception: pass` をテストコード内で使う（失敗を隠す）
- `time.sleep` での同期待ち（フレーキーになる。`AsyncMock` / `monkeypatch` を使う）
- 過剰モック: DB セッション全体をモックする等。実 DB セッションを使うこと
- **テストでグローバル event loop（`asyncio.set_event_loop` / `get_event_loop`）を触る**: スイートが同一プロセスで複数回実行される環境（mutation テスト等）で状態が漏れて落ちる。async は `loop = asyncio.new_event_loop(); try: loop.run_until_complete(...); finally: loop.close()` の分離パターンで実行する
