"""バックグラウンドタスクのワーカー。

ローカル: LocalDispatcher（FastAPI BackgroundTasks）から呼ばれる。
マネージドキュー導入時も同じ ``execute_task`` を経由してハンドラレジストリに
ディスパッチする（呼び出し元が retry_count を渡す形に拡張する）。

タスク種別ごとの実体は ``services/tasks/handlers/`` 配下に分離されている。
worker は状態遷移（processing → completed / retrying / dead_letter）と
リトライ判定などのタスク横断ロジックのみを担う。

セッション管理ポリシー:
  - ハンドラには ``SessionLocal``（ファクトリ）をそのまま渡し、ハンドラ内で
    長時間処理の前後にセッションを開閉する。
  - worker の状態遷移更新はハンドラとは独立した新規セッションで実行する。
    ハンドラ側のセッションが失効・破損していても、終端ステータスを確実に
    DB へ永続化するため。
"""

import logging
import time
from datetime import datetime, timezone

from app.db.database import SessionLocal
from app.models.task import AsyncTask
from app.services.tasks.exceptions import NonRetryableError
from app.services.tasks.handlers import get_handler

logger = logging.getLogger(__name__)

# duration_ms がこの閾値を超えたら WARNING を出す（5分）
_SLOW_TASK_THRESHOLD_MS = 300_000


def _monotonic_ms_since(start: float) -> int:
    """``time.monotonic()`` の開始時点からの経過ミリ秒を返す。"""
    return int((time.monotonic() - start) * 1000)


def _update_task(task_id: str, **fields: object) -> None:
    """独立セッションで AsyncTask レコードを更新する（終端状態の確実な永続化）。"""
    session = SessionLocal()
    try:
        task = session.get(AsyncTask, task_id)
        if task is None:
            logger.error("AsyncTask レコードが見つかりません: %s", task_id)
            return
        for name, value in fields.items():
            setattr(task, name, value)
        session.commit()
    finally:
        session.close()


async def execute_task(task_id: str) -> None:
    """AsyncTask レコード（id）を実行し、状態遷移を永続化する。

    遷移: processing → completed
                     → dead_letter （NonRetryableError / リトライ枯渇）
                     → retrying    （未分類例外かつ試行回数が残っている場合）

    retrying への遷移は「再試行の余地がある」ことの記録であり、再実行そのもの
    （再エンキュー）はディスパッチャー側の責務。ローカル（max_attempts=1）では
    未分類例外も最終試行扱いとなり dead_letter に落ちる。
    """
    session = SessionLocal()
    try:
        task = session.get(AsyncTask, task_id)
        if task is None:
            logger.error("AsyncTask レコードが見つかりません: %s", task_id)
            return
        task_type = task.task_type
        payload = dict(task.payload)
        retry_count = task.retry_count
        max_attempts = task.max_attempts
        task.status = "processing"
        task.started_at = datetime.now(timezone.utc)
        session.commit()
    finally:
        session.close()

    start = time.monotonic()
    logger.info(
        "タスク開始",
        extra={
            "task_id": task_id,
            "task_type": task_type,
            "status": "processing",
            "retry_count": retry_count,
            "max_attempts": max_attempts,
        },
    )

    handler = get_handler(task_type)
    if handler is None:
        # 種別の登録漏れは実装バグ。黙って completed にせず dead_letter で表明する
        logger.error("不明なタスク種別: %s", task_type)
        _update_task(
            task_id,
            status="dead_letter",
            error_message=f"未登録のタスク種別: {task_type}",
            completed_at=datetime.now(timezone.utc),
        )
        return

    try:
        # ハンドラレジストリ経由でディスパッチする（種別ごとの if 分岐は持たない）。
        # ハンドラには SessionLocal（ファクトリ）を渡し、ハンドラ内で開閉させる。
        await handler.run(SessionLocal, payload)

        duration_ms = _monotonic_ms_since(start)
        logger.info(
            "タスク完了",
            extra={
                "task_id": task_id,
                "task_type": task_type,
                "status": "completed",
                "duration_ms": duration_ms,
                "retry_count": retry_count,
            },
        )
        if duration_ms > _SLOW_TASK_THRESHOLD_MS:
            logger.warning(
                "タスクが低速です (%d ms)",
                duration_ms,
                extra={"task_id": task_id, "task_type": task_type, "duration_ms": duration_ms},
            )
        _update_task(task_id, status="completed", completed_at=datetime.now(timezone.utc))
    except NonRetryableError as exc:
        logger.warning(
            "タスク失敗（リトライ不可）",
            extra={
                "task_id": task_id,
                "task_type": task_type,
                "status": "dead_letter",
                "error_type": type(exc).__name__,
                "duration_ms": _monotonic_ms_since(start),
                "retry_count": retry_count,
            },
            exc_info=True,
        )
        _update_task(
            task_id,
            status="dead_letter",
            error_message=str(exc),
            completed_at=datetime.now(timezone.utc),
        )
    except Exception as exc:
        is_final = retry_count >= max_attempts - 1
        if is_final:
            logger.error(
                "タスクが最終試行で失敗しました (dead_letter)",
                extra={
                    "task_id": task_id,
                    "task_type": task_type,
                    "status": "dead_letter",
                    "error_type": type(exc).__name__,
                    "duration_ms": _monotonic_ms_since(start),
                    "retry_count": retry_count,
                    "max_attempts": max_attempts,
                },
                exc_info=True,
            )
            _update_task(
                task_id,
                status="dead_letter",
                error_message=str(exc),
                completed_at=datetime.now(timezone.utc),
            )
        else:
            logger.warning(
                "タスク失敗（リトライ予定）",
                extra={
                    "task_id": task_id,
                    "task_type": task_type,
                    "status": "retrying",
                    "error_type": type(exc).__name__,
                    "duration_ms": _monotonic_ms_since(start),
                    "retry_count": retry_count,
                    "max_attempts": max_attempts,
                },
                exc_info=True,
            )
            _update_task(
                task_id,
                status="retrying",
                error_message=str(exc),
                retry_count=retry_count + 1,
            )
