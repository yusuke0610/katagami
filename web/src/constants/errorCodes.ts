/**
 * バックエンドが返すエラーコードの SSoT 型定義。
 *
 * ## 同期ルール
 *
 * 本ファイルは backend の `backend/app/core/errors.py:ErrorCode` enum と
 * 完全に同じキー集合を保つ必要がある。
 *
 * - BE で新しい ErrorCode を追加 → 本ファイルにもキーを追加し、
 *   `web/src/constants/errorMessages.ts` の `ERROR_CONFIG` にメッセージと recovery を追加すること
 * - キー名・値の rename も両側を同時に変更すること
 *
 * 型システム上は `ERROR_CONFIG` を `Record<ErrorCodeKey, ...>` で縛ることで、
 * キーの網羅漏れを TypeScript の型エラーとして検出できる。
 * 集合一致自体は `scripts/lint-env-keys.sh`（`make lint-env-keys` / CI）が機械検証する。
 *
 * 関連: `backend/app/core/errors.py`, `web/src/utils/appError.ts`
 */

export const ERROR_CODES = [
  // バリデーション
  "VALIDATION_ERROR",
  // サーバー
  "INTERNAL_ERROR",
] as const;

export type ErrorCodeKey = (typeof ERROR_CODES)[number];

export function isErrorCode(value: unknown): value is ErrorCodeKey {
  return (
    typeof value === "string" &&
    (ERROR_CODES as readonly string[]).includes(value)
  );
}
