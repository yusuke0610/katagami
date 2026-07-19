from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class NoteCreate(BaseModel):
    """メモ作成リクエスト。"""

    title: str = Field(min_length=1, max_length=200)
    body: str = Field(min_length=1)


class NoteUpdate(BaseModel):
    """メモ更新リクエスト（部分更新）。"""

    title: str | None = Field(default=None, min_length=1, max_length=200)
    body: str | None = Field(default=None, min_length=1)


class NoteResponse(BaseModel):
    """メモ応答。"""

    model_config = ConfigDict(from_attributes=True)

    id: str
    title: str
    body: str
    summary: str | None
    created_at: datetime
    updated_at: datetime


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
