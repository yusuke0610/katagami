---
paths:
  - backend/**
---

# 非同期タスク基盤ルール

基盤コード: `app/services/tasks/`（worker / handlers / dispatcher）と `app/models/task.py`（AsyncTask）。

## ハンドラの実装規約

- タスク種別の実体は `app/services/tasks/handlers/` にモジュールを置き、
  `@register_handler("<task_type>")` で登録する。**worker に種別の if 分岐を足さない**
  （レジストリ経由に統一。未登録種別は dead_letter で表明される）
- **失敗を握りつぶして黙って return しない**。失敗は必ず例外で表明する
- 例外は可能な限り分類する: 一時的（タイムアウト / 5xx / レート制限）→ `RetryableError`、
  恒久的（バリデーション / 401/403/404）→ `NonRetryableError`
- DB を使う場合は渡された session_factory から自前で開閉する（長時間処理中に
  セッションを持ちっぱなしにしない）

## 状態遷移（worker が管理）

```
pending → processing → completed
                     → retrying     （未分類例外 かつ 試行回数が残っている）
                     → dead_letter  （NonRetryableError / リトライ枯渇 / 種別未登録）
```

- 終端状態の更新はハンドラと独立したセッションで行う（worker 実装済み。変えない）
- ハンドラを追加・変更したら、成功 / NonRetryableError / 未分類例外の 3 パスの
  状態遷移テストを `tests/test_worker.py` に随伴させる

## ディスパッチ

- 呼び出し側は `create_and_dispatch_task()`（dispatch_service）を使う。
  レコード作成と実行を分離し、API 応答時点で task_id を返す（クライアントは
  status をポーリングする）
- ローカルは `LocalDispatcher`（BackgroundTasks / max_attempts=1・自動リトライなし）。
  マネージドキュー導入時は `TaskDispatcher` 実装を差し替える
