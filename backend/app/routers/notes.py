from fastapi import APIRouter, BackgroundTasks, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import ErrorCode, raise_app_error
from app.db import get_db
from app.models.note import Note
from app.schemas.note import NoteCreate, NoteResponse, NoteUpdate
from app.schemas.task import TaskAccepted
from app.services.tasks.dispatch_service import create_and_dispatch_task
from app.services.tasks.local import LocalDispatcher

router = APIRouter(prefix="/api/notes", tags=["notes"])


def _get_note_or_404(db: Session, note_id: str) -> Note:
    note = db.get(Note, note_id)
    if note is None:
        raise_app_error(
            status_code=404,
            code=ErrorCode.VALIDATION_ERROR,
            message="メモが見つかりません。",
            action="ID を確認してください",
        )
    return note


@router.get("")
def list_notes(db: Session = Depends(get_db)) -> list[NoteResponse]:
    notes = db.scalars(select(Note).order_by(Note.created_at.desc())).all()
    return [NoteResponse.model_validate(note) for note in notes]


@router.post("", status_code=201)
def create_note(payload: NoteCreate, db: Session = Depends(get_db)) -> NoteResponse:
    note = Note(title=payload.title, body=payload.body)
    db.add(note)
    db.commit()
    db.refresh(note)
    return NoteResponse.model_validate(note)


@router.get("/{note_id}")
def get_note(note_id: str, db: Session = Depends(get_db)) -> NoteResponse:
    return NoteResponse.model_validate(_get_note_or_404(db, note_id))


@router.put("/{note_id}")
def update_note(note_id: str, payload: NoteUpdate, db: Session = Depends(get_db)) -> NoteResponse:
    note = _get_note_or_404(db, note_id)
    if payload.title is not None:
        note.title = payload.title
    if payload.body is not None:
        note.body = payload.body
    db.commit()
    db.refresh(note)
    return NoteResponse.model_validate(note)


@router.delete("/{note_id}", status_code=204)
def delete_note(note_id: str, db: Session = Depends(get_db)) -> None:
    note = _get_note_or_404(db, note_id)
    db.delete(note)
    db.commit()


@router.post("/{note_id}/summarize", status_code=202)
async def summarize_note(
    note_id: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
) -> TaskAccepted:
    """サマリ生成を非同期タスクとして受理する。

    202 + task_id を即時返却し、実行は非同期タスク基盤（worker）に委譲する。
    進捗は GET /api/tasks/{task_id} でポーリングする。
    """
    note = _get_note_or_404(db, note_id)
    task = await create_and_dispatch_task(
        db,
        LocalDispatcher(background_tasks),
        task_type="note_summarize",
        payload={"note_id": note.id},
    )
    return TaskAccepted(task_id=task.id)
