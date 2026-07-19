"""タスクハンドラのレジストリ。

タスク種別ごとの実体（ハンドラ）は本パッケージ配下にモジュールとして置き、
``@register_handler("<task_type>")`` で登録する。worker はレジストリ経由で
ディスパッチし、種別ごとの if 分岐を持たない（分岐の書き忘れで黙って
completed になる事故を構造的に防ぐ）。
"""

from collections.abc import Callable

from app.services.tasks.handlers.base import TaskHandler

_registry: dict[str, TaskHandler] = {}


def register_handler(task_type: str) -> Callable[[type[TaskHandler]], type[TaskHandler]]:
    """ハンドラクラスをタスク種別に紐付けて登録するデコレータ。"""

    def _decorator(handler_cls: type[TaskHandler]) -> type[TaskHandler]:
        _registry[task_type] = handler_cls()
        return handler_cls

    return _decorator


def get_handler(task_type: str) -> TaskHandler | None:
    """タスク種別に対応するハンドラを返す（未登録なら None）。"""
    return _registry.get(task_type)
