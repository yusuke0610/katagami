"""サンプルドメイン（Note CRUD + サマリ生成タスク）の統合テスト。

全縦串の貫通を検証する:
- DB 基盤（実 SQLite セッション）
- エラー契約（404 が AppErrorResponse 形で返る）
- 非同期タスク基盤（202 受理 → BackgroundTasks 実行 → status ポーリング）
"""

from app.main import app
from fastapi.testclient import TestClient

client = TestClient(app)


def _create_note(title: str = "テストメモ", body: str = "本文です。詳細な続き。") -> dict:
    response = client.post("/api/notes", json={"title": title, "body": body})
    assert response.status_code == 201
    return response.json()


def test_create_and_get_note() -> None:
    note = _create_note()
    assert note["title"] == "テストメモ"
    assert note["summary"] is None

    fetched = client.get(f"/api/notes/{note['id']}")
    assert fetched.status_code == 200
    assert fetched.json()["body"] == "本文です。詳細な続き。"


def test_list_notes_contains_created_note() -> None:
    note = _create_note(title="一覧テスト")
    response = client.get("/api/notes")
    assert response.status_code == 200
    assert any(item["id"] == note["id"] for item in response.json())


def test_update_note_partially() -> None:
    note = _create_note()
    response = client.put(f"/api/notes/{note['id']}", json={"title": "更新後タイトル"})
    assert response.status_code == 200
    body = response.json()
    assert body["title"] == "更新後タイトル"
    assert body["body"] == "本文です。詳細な続き。"


def test_delete_note() -> None:
    note = _create_note()
    assert client.delete(f"/api/notes/{note['id']}").status_code == 204
    assert client.get(f"/api/notes/{note['id']}").status_code == 404


def test_get_missing_note_returns_error_contract() -> None:
    response = client.get("/api/notes/no-such-id")
    assert response.status_code == 404
    body = response.json()
    # エラー契約（AppErrorResponse 形）で返ること
    assert body["code"] == "VALIDATION_ERROR"
    assert body["message"] == "メモが見つかりません。"
    assert "error_id" in body


def test_create_note_with_empty_title_is_rejected() -> None:
    response = client.post("/api/notes", json={"title": "", "body": "本文"})
    assert response.status_code == 422
    assert response.json()["code"] == "VALIDATION_ERROR"


def test_summarize_note_end_to_end() -> None:
    """202 受理 → バックグラウンド実行 → summary 書き戻し → タスク completed。"""
    note = _create_note(body="最初の文。二番目の文。")

    accepted = client.post(f"/api/notes/{note['id']}/summarize")
    assert accepted.status_code == 202
    task_id = accepted.json()["task_id"]

    # TestClient は応答返却後に BackgroundTasks を同期実行するため、この時点で完了している
    task = client.get(f"/api/tasks/{task_id}")
    assert task.status_code == 200
    assert task.json()["status"] == "completed"
    assert task.json()["task_type"] == "note_summarize"

    summarized = client.get(f"/api/notes/{note['id']}")
    assert summarized.json()["summary"] == "最初の文"


def test_summarize_missing_note_returns_404() -> None:
    response = client.post("/api/notes/no-such-id/summarize")
    assert response.status_code == 404
    assert response.json()["code"] == "VALIDATION_ERROR"


def test_get_missing_task_returns_error_contract() -> None:
    response = client.get("/api/tasks/no-such-task")
    assert response.status_code == 404
    assert response.json()["code"] == "VALIDATION_ERROR"
