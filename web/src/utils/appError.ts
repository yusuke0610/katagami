import { ERROR_CONFIG } from "../constants/errorMessages";
import { isErrorCode } from "../constants/errorCodes";
import { generateErrorId } from "./errorId";

/**
 * backend のエラー契約（AppErrorResponse）を FE で扱うための共通形。
 * code は errorCodes.ts の集合に無ければ INTERNAL_ERROR として扱う。
 */
export type AppErrorState = {
  code: string;
  message: string;
  action: string | null;
  retryAfter: number | null;
  errorId: string;
};

type ApiErrorInit = {
  code?: string;
  message: string;
  action?: string | null;
  retryAfter?: number | null;
  errorId?: string | null;
};

/** API 応答（AppErrorResponse）由来のエラー。 */
export class ApiError extends Error {
  code: string;
  action: string | null;
  retryAfter: number | null;
  errorId: string;

  constructor({
    code = "INTERNAL_ERROR",
    message,
    action = null,
    retryAfter = null,
    errorId,
  }: ApiErrorInit) {
    super(message);
    this.name = "ApiError";
    this.code = code;
    this.action = action;
    this.retryAfter = retryAfter;
    this.errorId = errorId ?? generateErrorId();
  }
}

export function isApiError(error: unknown): error is ApiError {
  return error instanceof ApiError;
}

/** AppErrorResponse 形の JSON body から ApiError を組み立てる。 */
export function apiErrorFromResponseBody(body: unknown): ApiError {
  if (typeof body === "object" && body !== null) {
    const record = body as Record<string, unknown>;
    if (typeof record.message === "string") {
      return new ApiError({
        code: isErrorCode(record.code) ? record.code : "INTERNAL_ERROR",
        message: record.message,
        action: typeof record.action === "string" ? record.action : null,
        retryAfter:
          typeof record.retry_after === "number" ? record.retry_after : null,
        errorId: typeof record.error_id === "string" ? record.error_id : null,
      });
    }
  }
  return new ApiError({ message: ERROR_CONFIG.INTERNAL_ERROR.message });
}

/** 任意の例外を表示用の AppErrorState へ正規化する。 */
export function toAppError(
  error: unknown,
  fallbackMessage = ERROR_CONFIG.INTERNAL_ERROR.message,
): AppErrorState {
  if (isApiError(error)) {
    return {
      code: error.code,
      message: error.message,
      action: error.action,
      retryAfter: error.retryAfter,
      errorId: error.errorId,
    };
  }

  if (error instanceof Error) {
    return {
      code: "INTERNAL_ERROR",
      message: error.message || fallbackMessage,
      action: null,
      retryAfter: null,
      errorId: generateErrorId(),
    };
  }

  return {
    code: "INTERNAL_ERROR",
    message: fallbackMessage,
    action: null,
    retryAfter: null,
    errorId: generateErrorId(),
  };
}
