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

export async function fetchHealth(baseUrl = ""): Promise<HealthResponse> {
  const response = await fetch(`${baseUrl}/health`);
  if (!response.ok) {
    throw apiErrorFromResponseBody(await parseJsonSafely(response));
  }
  return (await response.json()) as HealthResponse;
}
