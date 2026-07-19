import type { paths } from "./generated";
import { requestJson } from "./client";

/**
 * サンプルドメイン（Note）の型付き API モジュール。
 * すべての型は generated.ts（backend の Pydantic schema のミラー）から取り、
 * 手書きの型定義を持たない（型契約の縦串）。
 */

export type Note =
  paths["/api/notes/{note_id}"]["get"]["responses"]["200"]["content"]["application/json"];
export type NoteCreate =
  paths["/api/notes"]["post"]["requestBody"]["content"]["application/json"];
export type NoteUpdate =
  paths["/api/notes/{note_id}"]["put"]["requestBody"]["content"]["application/json"];
export type TaskAccepted =
  paths["/api/notes/{note_id}/summarize"]["post"]["responses"]["202"]["content"]["application/json"];
export type TaskStatus =
  paths["/api/tasks/{task_id}"]["get"]["responses"]["200"]["content"]["application/json"];

const JSON_HEADERS = { "Content-Type": "application/json" };

export function listNotes(): Promise<Note[]> {
  return requestJson<Note[]>("/api/notes");
}

export function createNote(payload: NoteCreate): Promise<Note> {
  return requestJson<Note>("/api/notes", {
    method: "POST",
    headers: JSON_HEADERS,
    body: JSON.stringify(payload),
  });
}

export function getNote(noteId: string): Promise<Note> {
  return requestJson<Note>(`/api/notes/${noteId}`);
}

export function updateNote(noteId: string, payload: NoteUpdate): Promise<Note> {
  return requestJson<Note>(`/api/notes/${noteId}`, {
    method: "PUT",
    headers: JSON_HEADERS,
    body: JSON.stringify(payload),
  });
}

export function deleteNote(noteId: string): Promise<void> {
  return requestJson<void>(`/api/notes/${noteId}`, { method: "DELETE" });
}

export function summarizeNote(noteId: string): Promise<TaskAccepted> {
  return requestJson<TaskAccepted>(`/api/notes/${noteId}/summarize`, {
    method: "POST",
  });
}

export function getTask(taskId: string): Promise<TaskStatus> {
  return requestJson<TaskStatus>(`/api/tasks/${taskId}`);
}
