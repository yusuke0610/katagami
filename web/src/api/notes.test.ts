import { afterEach, describe, expect, it, vi } from "vitest";
import { isApiError } from "../utils/appError";
import { createNote, deleteNote, getTask, summarizeNote } from "./notes";

function mockFetchOnce(
  status: number,
  body: unknown,
): ReturnType<typeof vi.fn> {
  const mock = vi.fn().mockResolvedValue(
    body === null
      ? new Response(null, { status })
      : new Response(JSON.stringify(body), {
          status,
          headers: { "Content-Type": "application/json" },
        }),
  );
  vi.stubGlobal("fetch", mock);
  return mock;
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("createNote", () => {
  it("201 応答を型付きで返す", async () => {
    mockFetchOnce(201, {
      id: "note-1",
      title: "タイトル",
      body: "本文",
      summary: null,
      created_at: "2026-07-19T00:00:00Z",
      updated_at: "2026-07-19T00:00:00Z",
    });
    const note = await createNote({ title: "タイトル", body: "本文" });
    expect(note.id).toBe("note-1");
    expect(note.summary).toBeNull();
  });

  it("バリデーションエラーは ApiError（エラー契約）として投げる", async () => {
    mockFetchOnce(422, {
      code: "VALIDATION_ERROR",
      message: "入力内容が正しくありません。",
      error_id: "abcdef123456",
    });
    const error = await createNote({ title: "", body: "" }).catch(
      (e: unknown) => e,
    );
    expect(isApiError(error)).toBe(true);
    if (isApiError(error)) {
      expect(error.code).toBe("VALIDATION_ERROR");
    }
  });
});

describe("deleteNote", () => {
  it("204 応答を void として扱う", async () => {
    mockFetchOnce(204, null);
    await expect(deleteNote("note-1")).resolves.toBeUndefined();
  });
});

describe("summarizeNote / getTask", () => {
  it("202 受理 → タスク status のポーリングまで型が通る", async () => {
    mockFetchOnce(202, { task_id: "task-1" });
    const accepted = await summarizeNote("note-1");
    expect(accepted.task_id).toBe("task-1");

    mockFetchOnce(200, {
      id: "task-1",
      task_type: "note_summarize",
      status: "completed",
      error_message: null,
    });
    const task = await getTask(accepted.task_id);
    expect(task.status).toBe("completed");
  });
});
