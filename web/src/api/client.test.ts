import { afterEach, describe, expect, it, vi } from "vitest";
import { isApiError } from "../utils/appError";
import { fetchHealth } from "./client";

function mockFetchOnce(status: number, body: unknown): void {
  vi.stubGlobal(
    "fetch",
    vi.fn().mockResolvedValue(
      new Response(JSON.stringify(body), {
        status,
        headers: { "Content-Type": "application/json" },
      }),
    ),
  );
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("fetchHealth", () => {
  it("200 応答を型付きで返す", async () => {
    mockFetchOnce(200, { status: "ok", version: "dev" });
    const health = await fetchHealth();
    expect(health.status).toBe("ok");
    expect(health.version).toBe("dev");
  });

  it("エラー応答は AppErrorResponse 契約として ApiError に正規化される", async () => {
    mockFetchOnce(500, {
      code: "INTERNAL_ERROR",
      message: "予期しないエラーが発生しました。",
      error_id: "abcdef123456",
    });
    const error = await fetchHealth().catch((e: unknown) => e);
    expect(isApiError(error)).toBe(true);
    if (isApiError(error)) {
      expect(error.code).toBe("INTERNAL_ERROR");
      expect(error.errorId).toBe("abcdef123456");
    }
  });

  it("JSON でないエラー応答も INTERNAL_ERROR へ fallback する", async () => {
    vi.stubGlobal(
      "fetch",
      vi
        .fn()
        .mockResolvedValue(new Response("gateway timeout", { status: 504 })),
    );
    const error = await fetchHealth().catch((e: unknown) => e);
    expect(isApiError(error)).toBe(true);
    if (isApiError(error)) {
      expect(error.code).toBe("INTERNAL_ERROR");
    }
  });
});
