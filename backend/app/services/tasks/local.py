"""ローカル環境用ディスパッチャー（FastAPI BackgroundTasks）。"""

from fastapi import BackgroundTasks

from app.services.tasks.base import TaskDispatcher
from app.services.tasks.worker import execute_task


class LocalDispatcher(TaskDispatcher):
    """FastAPI の BackgroundTasks でレスポンス返却後に同一プロセスで実行する。

    ローカル環境ではマネージドキューのネイティブリトライが使えないため、
    失敗したタスクは自動リトライされない（max_attempts=1 で dead_letter へ）。
    手動で再実行する前提。
    """

    def __init__(self, background_tasks: BackgroundTasks):
        self._bg = background_tasks

    async def dispatch(self, task_id: str) -> None:
        self._bg.add_task(execute_task, task_id)
