from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.errors import ErrorCode, raise_app_error
from app.db import get_db
from app.models.task import AsyncTask
from app.schemas.task import TaskStatusResponse

router = APIRouter(prefix="/api/tasks", tags=["tasks"])


@router.get("/{task_id}")
def get_task(task_id: str, db: Session = Depends(get_db)) -> TaskStatusResponse:
    """非同期タスクの実行状態を返す（クライアントのポーリング用）。"""
    task = db.get(AsyncTask, task_id)
    if task is None:
        raise_app_error(
            status_code=404,
            code=ErrorCode.VALIDATION_ERROR,
            message="タスクが見つかりません。",
            action="task_id を確認してください",
        )
    return TaskStatusResponse.model_validate(task)
