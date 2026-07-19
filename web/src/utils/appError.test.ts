import { describe, expect, it } from "vitest";
import { ERROR_CONFIG } from "../constants/errorMessages";
import {
  ApiError,
  apiErrorFromResponseBody,
  isApiError,
  toAppError,
} from "./appError";

describe("apiErrorFromResponseBody", () => {
  it("AppErrorResponse 形の body を ApiError に変換する", () => {
    const error = apiErrorFromResponseBody({
      code: "VALIDATION_ERROR",
      message: "入力内容が正しくありません。",
      action: "入力内容を見直してください",
      retry_after: 30,
      error_id: "abcdef123456",
    });
    expect(error.code).toBe("VALIDATION_ERROR");
    expect(error.message).toBe("入力内容が正しくありません。");
    expect(error.action).toBe("入力内容を見直してください");
    expect(error.retryAfter).toBe(30);
    expect(error.errorId).toBe("abcdef123456");
  });

  it("未知のエラーコードは INTERNAL_ERROR へ fallback する", () => {
    const error = apiErrorFromResponseBody({
      code: "UNKNOWN_CODE",
      message: "何かのエラー",
    });
    expect(error.code).toBe("INTERNAL_ERROR");
    expect(error.message).toBe("何かのエラー");
  });

  it("契約に沿わない body は既定の INTERNAL_ERROR メッセージになる", () => {
    const error = apiErrorFromResponseBody("plain text");
    expect(error.code).toBe("INTERNAL_ERROR");
    expect(error.message).toBe(ERROR_CONFIG.INTERNAL_ERROR.message);
    expect(error.errorId).toHaveLength(12);
  });
});

describe("toAppError", () => {
  it("ApiError は各フィールドを保持したまま正規化する", () => {
    const apiError = new ApiError({
      code: "VALIDATION_ERROR",
      message: "入力エラー",
      action: "見直してください",
    });
    const state = toAppError(apiError);
    expect(state.code).toBe("VALIDATION_ERROR");
    expect(state.message).toBe("入力エラー");
    expect(state.action).toBe("見直してください");
    expect(state.errorId).toHaveLength(12);
  });

  it("素の Error は INTERNAL_ERROR として正規化する", () => {
    const state = toAppError(new Error("boom"));
    expect(state.code).toBe("INTERNAL_ERROR");
    expect(state.message).toBe("boom");
    expect(state.action).toBeNull();
  });

  it("Error 以外の値は fallback メッセージになる", () => {
    const state = toAppError(undefined);
    expect(state.code).toBe("INTERNAL_ERROR");
    expect(state.message).toBe(ERROR_CONFIG.INTERNAL_ERROR.message);
  });
});

describe("isApiError", () => {
  it("ApiError インスタンスのみ true を返す", () => {
    expect(isApiError(new ApiError({ message: "x" }))).toBe(true);
    expect(isApiError(new Error("x"))).toBe(false);
    expect(isApiError(null)).toBe(false);
  });
});
