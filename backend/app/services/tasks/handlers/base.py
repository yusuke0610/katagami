"""タスクハンドラの基底定義。"""

from abc import ABC, abstractmethod
from collections.abc import Callable

from sqlalchemy.orm import Session

# ハンドラにはセッションそのものではなくファクトリを渡す。
# 長時間処理の前後でハンドラ自身がセッションを開閉することで、
# 接続の長期保持（タイムアウト・ロック）を避ける。
SessionFactory = Callable[[], Session]


class TaskHandler(ABC):
    """タスク種別ごとの実処理。

    実装規約:
    - 失敗を握りつぶして黙って return しない。失敗は必ず例外で表明する
      （分類できる場合は RetryableError / NonRetryableError で分類する）
    - DB を使う場合は session_factory から自前で開閉する
    """

    @abstractmethod
    async def run(self, session_factory: SessionFactory, payload: dict) -> None:
        """タスクを実行する。失敗は例外で表明する。"""
