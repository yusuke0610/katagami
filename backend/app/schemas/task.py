from pydantic import BaseModel, ConfigDict


class TaskAccepted(BaseModel):
    """非同期タスク受理応答。task_id で /api/tasks/{task_id} をポーリングする。"""

    task_id: str


class TaskStatusResponse(BaseModel):
    """非同期タスクの実行状態応答。"""

    model_config = ConfigDict(from_attributes=True)

    id: str
    task_type: str
    status: str
    error_message: str | None
