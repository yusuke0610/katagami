"""タスクの作成 + ディスパッチを一体で行うサービス。"""

from sqlalchemy.orm import Session

from app.models.task import AsyncTask
from app.services.tasks.base import TaskDispatcher


async def create_and_dispatch_task(
    db: Session,
    dispatcher: TaskDispatcher,
    *,
    task_type: str,
    payload: dict,
    max_attempts: int = 1,
) -> AsyncTask:
    """AsyncTask レコードを pending で作成し、ディスパッチャーに回す。

    レコード作成（同期・呼び出し元セッション）と実行（バックグラウンド・
    worker の独立セッション）を分離することで、API 応答時点で task_id を
    返せるようにする（クライアントは status をポーリングできる）。
    """
    task = AsyncTask(task_type=task_type, payload=payload, max_attempts=max_attempts)
    db.add(task)
    db.commit()
    db.refresh(task)

    await dispatcher.dispatch(task.id)
    return task
