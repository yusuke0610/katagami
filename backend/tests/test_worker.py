"""非同期タスク基盤（worker の状態遷移）のテスト。

fake ハンドラをレジストリに登録し、execute_task が AsyncTask レコードを
processing → completed / retrying / dead_letter へ正しく遷移させることを検証する。
"""

import asyncio
from collections.abc import Coroutine
from typing import Any

from app.db import SessionLocal
from app.models.task import AsyncTask
from app.services.tasks.exceptions import NonRetryableError
from app.services.tasks.handlers import register_handler
from app.services.tasks.handlers.base import SessionFactory, TaskHandler
from app.services.tasks.worker import execute_task


@register_handler("test_ok")
class _OkHandler(TaskHandler):
    async def run(self, session_factory: SessionFactory, payload: dict) -> None:
        return None


@register_handler("test_nonretryable")
class _NonRetryableHandler(TaskHandler):
    async def run(self, session_factory: SessionFactory, payload: dict) -> None:
        raise NonRetryableError("恒久的な失敗")


@register_handler("test_flaky")
class _FlakyHandler(TaskHandler):
    async def run(self, session_factory: SessionFactory, payload: dict) -> None:
        raise TimeoutError("一時的な失敗")


def _run(coro: Coroutine[Any, Any, None]) -> None:
    """グローバル event loop を汚さない分離パターンで coroutine を実行する。"""
    loop = asyncio.new_event_loop()
    try:
        loop.run_until_complete(coro)
    finally:
        loop.close()


def _create_task(task_type: str, *, max_attempts: int = 1) -> str:
    session = SessionLocal()
    try:
        task = AsyncTask(task_type=task_type, payload={"key": "value"}, max_attempts=max_attempts)
        session.add(task)
        session.commit()
        return task.id
    finally:
        session.close()


def _fetch_task(task_id: str) -> AsyncTask:
    session = SessionLocal()
    try:
        task = session.get(AsyncTask, task_id)
        assert task is not None
        return task
    finally:
        session.close()


def test_successful_task_transitions_to_completed() -> None:
    task_id = _create_task("test_ok")
    _run(execute_task(task_id))
    task = _fetch_task(task_id)
    assert task.status == "completed"
    assert task.started_at is not None
    assert task.completed_at is not None
    assert task.error_message is None


def test_nonretryable_error_transitions_to_dead_letter() -> None:
    task_id = _create_task("test_nonretryable", max_attempts=3)
    _run(execute_task(task_id))
    task = _fetch_task(task_id)
    # リトライ余地があっても NonRetryableError は即 dead_letter
    assert task.status == "dead_letter"
    assert task.error_message == "恒久的な失敗"
    assert task.retry_count == 0


def test_unclassified_error_on_final_attempt_transitions_to_dead_letter() -> None:
    task_id = _create_task("test_flaky", max_attempts=1)
    _run(execute_task(task_id))
    task = _fetch_task(task_id)
    assert task.status == "dead_letter"
    assert task.error_message == "一時的な失敗"


def test_unclassified_error_with_attempts_left_transitions_to_retrying() -> None:
    task_id = _create_task("test_flaky", max_attempts=3)
    _run(execute_task(task_id))
    task = _fetch_task(task_id)
    assert task.status == "retrying"
    assert task.retry_count == 1
    assert task.error_message == "一時的な失敗"


def test_unregistered_task_type_transitions_to_dead_letter() -> None:
    task_id = _create_task("no_such_type")
    _run(execute_task(task_id))
    task = _fetch_task(task_id)
    # 種別の登録漏れは黙って completed にしない（実装バグの表明）
    assert task.status == "dead_letter"
    assert task.error_message is not None
    assert "no_such_type" in task.error_message
