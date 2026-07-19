"""非同期タスク基盤の共通定義（ステータス集合とディスパッチャーインターフェース）。"""

from abc import ABC, abstractmethod

# 手動再実行を許可する終端状態の集合。
# `dead_letter`: リトライ枯渇またはリトライ不可エラーで停止した最終状態。
RETRYABLE_TERMINAL_STATUSES: frozenset[str] = frozenset({"dead_letter"})

# 進行中（pending / processing）とみなすステータス集合。
IN_PROGRESS_STATUSES: frozenset[str] = frozenset({"pending", "processing"})


def is_retryable_terminal(status: str | None) -> bool:
    """status が手動再実行可能な終端状態かどうかを返す。"""
    return status in RETRYABLE_TERMINAL_STATUSES


def is_in_progress(status: str | None) -> bool:
    """status が進行中（pending / processing）かどうかを返す。"""
    return status in IN_PROGRESS_STATUSES


class TaskDispatcher(ABC):
    """タスクをバックグラウンドにディスパッチする共通インターフェース。

    ローカルは FastAPI BackgroundTasks（LocalDispatcher）、本番はマネージドキュー
    （Cloud Tasks 等）に差し替える。呼び出し側はこのインターフェースだけに依存する。
    """

    @abstractmethod
    async def dispatch(self, task_id: str) -> None:
        """作成済み AsyncTask レコード（id）をバックグラウンド実行に回す。"""
