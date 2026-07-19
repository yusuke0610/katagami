import type { paths } from "./generated";
import { apiErrorFromResponseBody } from "../utils/appError";

/**
 * 型付き API クライアント（最小実装）。
 *
 * レスポンス型は openapi-typescript の生成物（generated.ts）から取り、
 * backend の Pydantic schema（SSoT）と機械的に同期させる。
 * エラーは AppErrorResponse 契約として ApiError に正規化して投げる。
 */

export type HealthResponse =
  paths["/health"]["get"]["responses"]["200"]["content"]["application/json"];

async function parseJsonSafely(response: Response): Promise<unknown> {
  try {
    return await response.json();
  } catch {
    return null;
  }
}

/**
 * JSON API への共通リクエスト。エラー応答は ApiError（AppErrorResponse 契約）として投げる。
 * 型引数 T は generated.ts のレスポンス型を渡す（手書き型の二重定義をしない）。
 */
export async function requestJson<T>(
  path: string,
  init?: RequestInit,
): Promise<T> {
  const response = await fetch(path, init);
  if (!response.ok) {
    throw apiErrorFromResponseBody(await parseJsonSafely(response));
  }
  if (response.status === 204) {
    return undefined as T;
  }
  return (await response.json()) as T;
}

export async function fetchHealth(baseUrl = ""): Promise<HealthResponse> {
  return requestJson<HealthResponse>(`${baseUrl}/health`);
}
