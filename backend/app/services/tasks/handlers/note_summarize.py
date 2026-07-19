"""メモのサマリ生成タスク（サンプルドメインの非同期タスク）。"""

from app.models.note import Note
from app.services.notes.summarizer import summarize
from app.services.tasks.exceptions import NonRetryableError
from app.services.tasks.handlers import register_handler
from app.services.tasks.handlers.base import SessionFactory, TaskHandler


@register_handler("note_summarize")
class NoteSummarizeHandler(TaskHandler):
    """payload の note_id のメモにサマリを書き戻す。

    メモが存在しない場合はリトライしても回復しないため NonRetryableError で表明する
    （黙って return しない）。
    """

    async def run(self, session_factory: SessionFactory, payload: dict) -> None:
        note_id = payload.get("note_id")
        if not isinstance(note_id, str) or not note_id:
            raise NonRetryableError("payload に note_id がありません")

        session = session_factory()
        try:
            note = session.get(Note, note_id)
            if note is None:
                raise NonRetryableError(f"メモが見つかりません: {note_id}")
            note.summary = summarize(note.body)
            session.commit()
        finally:
            session.close()
